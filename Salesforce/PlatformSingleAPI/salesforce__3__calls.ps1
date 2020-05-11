################################################
#
# TODO
#
################################################

# TODO [x] use parallel calls (think of the limits of concurrent calls)
# TODO [x] implement mutex and write every page directly to a file -> maybe not needed as you cannot paginate per object, you get the url to the next batch in the current call
# TODO [x] remove or escape linebreaks in fields
# TODO [x] implement batch (async) process


################################################
#
# PREPARATION / ASSEMBLIES
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 | ConvertFrom-Json

# access token path
$accesstokenpath = "$( $scriptPath )\access.token"


Add-Type -AssemblyName System.Web

#$VerbosePreference = "Continue"

################################################
#
# HIDE POWERSHELL
#
################################################

if ($settings.general.hidePowerShell -eq $true ) {

    Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
    '
    $consolePtr = [Console.Window]::GetConsoleWindow()
    [Console.Window]::ShowWindow($consolePtr, 0) 

}

########################################################################
#                                                                      #
# SETUP SETTINGS                                                       #
#                                                                      #
########################################################################


# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
$AllProtocols = [System.Net.SecurityProtocolType]'Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols


$throttle = $settings.general.throttle



########################################################################
#                                                                      #
# FUNCTIONS                                                            #
#                                                                      #
########################################################################

function ExitWithCode
{
    param
    (
        $exitcode
    )

    $host.SetShouldExit($exitcode)
    exit
} 

################################################
#
# PROCESS
#
################################################


$currentTimestamp = $(Get-Date -Format yyyyMMddHHmmss)

cd "$( $scriptPath )"
mkdir $currentTimestamp



# For first API call, check if unauthorized. If it is -> refresh the token
$tries = 0
do {    
    try {
        if ($tries -eq 1) { Write-Host "Refreshing token" }
        $accessToken = Get-Content $accesstokenpath
        $bearer = @{ "Authorization" = ("Bearer", $accessToken -join " ") }
        $res = Invoke-RestMethod -Uri "$( $settings.salesforce.uri.endpoint )sobjects/"  -Headers $bearer  -Method Get
    } catch {
        # 401 = unauthorized
        if ($_.Exception.Response.StatusCode.value__ -eq "401") { 
            powershell.exe -File "$( $scriptPath )\salesforce__1b__refresh.ps1"
        } 
    } 
} until ( $tries++ -eq 1 -or $res) # this gives us one retry

# Load configuration
$config = Get-Content -Path "$( $scriptPath )\configuration.json" -Encoding UTF8 | ConvertFrom-Json











# Define parallel job

$scriptBlockPhaseTwo = {

    Param (
        $parameters
    )
    
    $mtx = New-Object System.Threading.Mutex($false, "LogMutex")
    
    $objName = $parameters.SalesObject
    
    $mtx.WaitOne()
    Add-Content -Value "$(Get-Date -Format G) # Loading $( $objName )" -Path "$( $parameters.scriptPath )\$( $parameters.tstp )\status.log"
    [void]$mtx.ReleaseMutex()

    #$_.Value.fields
    $soqlEncoded = $parameters.SOQL
    [System.Uri]$url = $parameters.URL
    Add-Content -Value "$(Get-Date -Format G) # $( $url ) " -Path "$( $parameters.scriptPath )\$( $parameters.tstp )\status.log" 
    $loadedRecords = 0
    #Write-Host "Now loading!"
        Do {        
            $records = Invoke-RestMethod -Uri $url -Headers $parameters.bearer -Method Get
            $loadedRecords += $records.records.Count
            
            $mtx.WaitOne()
            Add-Content -Value "$(Get-Date -Format G) # Loaded $( $loadedRecords ) of $( $records.totalSize ) $( $objName )" -Path "$( $parameters.scriptPath )\$( $parameters.tstp )\status.log"
            [void]$mtx.ReleaseMutex()
            
            #$records.records | Out-GridView
            $records.records | Select * -ExcludeProperty attributes | Export-Csv -Delimiter "`t" -Encoding "UTF8" -Path "$( $parameters.scriptPath )\$( $parameters.tstp )\$( $objName ).csv" -NoTypeInformation -Append 
            If ($records.done -eq $false) {
                $url = "$( $url.Scheme )://$( $url.Host )$( $records.nextRecordsUrl )"
            }

        } Until ($records.done -eq $true)
    
    $mtx.WaitOne()
    Add-Content -Value "$(Get-Date -Format G) # Loaded $( $records.totalSize ) $( $objName ) in total" -Path "$( $parameters.scriptPath )\$( $parameters.tstp )\status.log"
    [void]$mtx.ReleaseMutex()
    
    return "done" # results already written in files, so no need to give back data

}






# Start parallelisation


$RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $throttle)
$RunspacePool.Open()
$Jobs = @()



# Fill queue for parallelisation -> one thread per object as every result contains the url to the next result in an object


$config.PSObject.Properties | ForEach {

    $soqlEncoded = [System.Web.HttpUtility]::UrlEncode( $_.Value.soql )

    

    $arguments = @{
        SalesObject=$_.Name;
        SOQL=$soqlEncoded;
        URL="$( $settings.salesforce.uri.endpoint )query?q=$( $soqlEncoded )";
        bearer=$bearer;
        tstp=$currentTimestamp;
        scriptPath=$scriptPath
    }

   # Write-Host $arguments.URL

    #Write-Host "$($limitPerPage * $_)"

   $Job = [powershell]::Create().AddScript($scriptBlockPhaseTwo).AddArgument($arguments)
   $Job.RunspacePool = $RunspacePool
   $Jobs += New-Object PSObject -Property @{
        RunNum = $_
        Pipe = $Job
        Result = $Job.BeginInvoke()
    }

}




$mtx = New-Object System.Threading.Mutex($false, "LogMutex")
$mtx.WaitOne()
Add-Content -Value "$(Get-Date -Format G) # Waiting..." -Path "$( $currentTimestamp )\status.log"
[void]$mtx.ReleaseMutex()



$currentLine = 0
$end = -1
Do {

   
   $lines = Get-Content -path "$( $currentTimestamp )\status.log"
   $lines | Select -Skip $currentLine
   $currentLine = ( $lines | Measure-Object -Line ).Lines

   

   Write-Host "$(Get-Date -Format G) # Finished $( ($Jobs.Result.IsCompleted | group | where { $_.Name -eq $true }).Count ) of $($Jobs.Result.Count)"
   Start-Sleep -Milliseconds 500

   # mechanism to show the last lines
   if ($end -eq 0) {
    $end = 1
   }
   if ($Jobs.Result.IsCompleted -notcontains $false -and $end -lt 0) {
    $end = 0
   }

} Until ( $end -eq 1)
Write-Host "$(Get-Date -Format G) # All jobs completed!"

        cd "$( $currentTimestamp )"
        Copy-Item "*.csv" "..\..\data\" -Force

