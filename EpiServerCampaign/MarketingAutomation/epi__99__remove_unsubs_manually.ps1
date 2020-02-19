################################################
#
# INPUT
#
################################################

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $false



################################################
#
# NOTES
#
################################################

<#

https://world.episerver.com/documentation/developer-guides/campaign/SOAP-API/unsubscribewebservice/contains/

#>

################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

Set-Location -Path $scriptPath


# General settings
$functionsSubfolder = "functions"
$settingsFilename = "settings.json"
$moduleName = "REMOVEUNSUBS"
$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        ,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile
$fileToAdd = "D:\Apteco\Publish\Handel\public\97_Input\removed_unsubscribes.csv"
$stringToLog = "Abmeldung manuell entfernt" # If you want a timestamp to import in FastStats, you could use this value instead [datetime]::Now.ToString("yyyyMMddHHmmss")

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS
#
################################################

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"


################################################
#
# PROGRAM
#
################################################


#-----------------------------------------------
# INPUT ID
#-----------------------------------------------

$userID = ""
$userID = Read-Host "Please enter the user id in epi (same as customer id)"


if ( $userID -ne "" ) {
    
    Write-Log -message "Entered the user id ""$( $userID )"""
    
    #-----------------------------------------------
    # CREATE EPI SESSION
    #-----------------------------------------------

    Get-EpiSession


    #-----------------------------------------------
    # CHECK IF ENTRY IS UNSUBSCRIBED
    #-----------------------------------------------

    $statusBeforeUpdate = Invoke-Epi -webservice "Unsubscribe" -method "contains" -param @(@{value=$userID;datatype="string"}) -useSessionId $true

    if ($statusBeforeUpdate) {

        #-----------------------------------------------
        # REMOVE UNSUBSCRIBED STATUS
        #-----------------------------------------------

        Invoke-Epi -webservice "Unsubscribe" -method "remove" -param @(@{value=$userID;datatype="string"}) -useSessionId $true
        Write-Log -message "Removed user from the epi unsubscribe list"


        #-----------------------------------------------
        # CHECK AGAIN
        #-----------------------------------------------

        $statusAfterUpdate = Invoke-Epi -webservice "Unsubscribe" -method "contains" -param @(@{value=$userID;datatype="string"}) -useSessionId $true

        if (!$statusAfterUpdate) {
        
            #-----------------------------------------------
            # ADD REMOVED UNSUBSCRIBED TO A LIST
            #-----------------------------------------------

            "$( $userID )`t$( $stringToLog )" | Out-File -FilePath $fileToAdd -Encoding ascii -Append
            Write-Log -message "Written user id to file $( $fileToAdd )"

        }


    } else {

        Write-Log -message "user id is not unsubscribe list online"

    }

} else {
    
    Write-Log -message "Empty user id - nothing to do"

}

Write-Log -message "Done"
