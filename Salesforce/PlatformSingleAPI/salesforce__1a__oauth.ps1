################################################
#
# TODO
#
################################################

# TODO [x] separate settings into json file
# TODO [x] change everything from winforms to WPF
# TODO [ ] show available tables from datamodel
# TODO [ ] make and remember selected fields from salesforce
# TODO [x] possibility to influence SOQL?
# TODO [ ] creation of access token when cancel the window?



################################################
#
# LINKS
#
################################################

<#

Use WPF through powershell
https://github.com/JimMoyle/GUIDemo/blob/master/Ep1%20WPFGUIinTenLines/PoSHGUI.ps1#L36
https://blogs.technet.microsoft.com/heyscriptingguy/2014/08/01/ive-got-a-powershell-secret-adding-a-gui-to-scripts/

Use Inline Formatting for WPF Textblocks
http://www.wpf-tutorial.com/basic-controls/the-textblock-control-inline-formatting/

Use objects directly
https://www.safaribooksonline.com/library/view/windows-powershell-cookbook/9780596528492/ch03s06.html


#>




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


# Load assemblies for GeckoFX/Firefox
$assemblyCore = [Reflection.Assembly]::LoadFile( ( Get-ChildItem -Path $scriptPath -Recurse -Filter "Geckofx-Core.dll" | Select -First 1 ).FullName )
$assemblyWinforms = [Reflection.Assembly]::LoadFile( ( Get-ChildItem -Path $scriptPath -Recurse -Filter "Geckofx-Winforms.dll" | Select -First 1 ).FullName )

# Load more assemblies for WPF
Add-Type -AssemblyName presentationframework, presentationcore, WindowsFormsIntegration
Add-Type -AssemblyName System.Windows.Forms, System.Web
[System.Windows.Forms.Application]::EnableVisualStyles();



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
# SETTINGS                                                             #
#                                                                      #
########################################################################


#The resource URI
$resource = $settings.salesforce.uri.resource
$authUri = $settings.salesforce.uri.authUri
$tokenUri = $settings.salesforce.uri.tokenUri
$testUri = $settings.salesforce.uri.testUri

#Your Client ID and Client Secret obainted when registering your WebApp
$clientid = $settings.salesforce.authentication.clientid
$clientSecret = $settings.salesforce.authentication.clientSecret

#Your Reply URL configured when registering your WebApp
$redirectUri = $settings.salesforce.uri.redirectUri

#Scope
$scope = $settings.salesforce.authentication.scope

#UrlEncode the ClientID and ClientSecret and URL's for special characters
$clientSecretEncoded = [System.Web.HttpUtility]::UrlEncode($clientSecret)
$resourceEncoded = [System.Web.HttpUtility]::UrlEncode($resource)
$scopeEncoded = [System.Web.HttpUtility]::UrlEncode($scope)

#Refresh Token Path
$refreshtokenpath = "$( $scriptPath )\refresh.token"
$accesstokenpath = "$( $scriptPath )\access.token"

# Icon for wpf (much more complicated than for winforms, where you only would need the first step)
$icon = [System.Drawing.Icon]::ExtractAssociatedIcon($settings.general.iconSource) 
[System.Drawing.Bitmap]$bmp = $icon.ToBitmap()
$stream = New-Object -TypeName System.IO.MemoryStream
$bmp.save($stream, [System.Drawing.Imaging.ImageFormat]::Png.Guid)
[System.Windows.Media.ImageSource]$iconSource = [System.Windows.Media.Imaging.BitmapFrame]::Create($stream)


$xamlFile = $settings.general.xamlAuth





################################################
#
# LOAD WPF XAML
#
################################################


$wpf = @{  }

$inputXml = Get-Content -Path $xamlFile
$inputXMLClean = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace 'x:Class=".*?"','' -replace 'd:DesignHeight="\d*?"','' -replace 'd:DesignWidth="\d*?"',''
[xml]$xaml = $inputXMLClean
$reader = New-Object System.Xml.XmlNodeReader $xaml

$tempform = [Windows.Markup.XamlReader]::Load($reader)

$namedNodes = $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")

#add all the named nodes as members to the $wpf variable, this also adds in the correct type for the objects.
$namedNodes | ForEach-Object {
	$wpf.Add($_.Name, $tempform.FindName($_.Name))
}


################################################
#
# SETUP ELEMENTS
#
################################################

[Gecko.Xpcom]::Initialize("$( $scriptPath )\geckofx\Firefox")
$browser = New-Object -TypeName Gecko.GeckoWebBrowser -Property @{ Dock=[System.Windows.Forms.DockStyle]::Fill.value__ }

$formHost = [System.Windows.Forms.Integration.WindowsFormsHost]::new() 
$formhost.Child = $browser
$wpf.gridBrowser.Children.add($formhost)


# add formatted text
$wpf.textblockDescription.Inlines.Clear()
$wpf.textblockDescription.Inlines.Add("Please log into your salesforce account. If you are allowed to access data via the API we will receive an access and refresh token automatically. The window will then close automatically and proceeds to the next step.");
<#
$wpf.textblockDescription.Inlines.Add( (New-Object -TypeName System.Windows.Documents.Run -Property @{ Text="the TextBlock control "; FontWeight=[System.Windows.FontWeights]::Bold }) );
$wpf.textblockDescription.Inlines.Add("using ");
$wpf.textblockDescription.Inlines.Add( (New-Object -TypeName System.Windows.Documents.Run -Property @{ Text="inline ";FontStyle=[System.Windows.FontStyles]::Italic }) );
$wpf.textblockDescription.Inlines.Add( (New-Object -TypeName System.Windows.Documents.Run -Property @{ Text="text formatting ";Foreground = [System.Windows.Media.Brushes]::Blue }) );
$wpf.textblockDescription.Inlines.Add("from ");
$wpf.textblockDescription.Inlines.Add( (New-Object -TypeName System.Windows.Documents.Run -Property @{ Text="Code-Behind";TextDecorations = [System.Windows.TextDecorations]::Underline }) );
$wpf.textblockDescription.Inlines.Add(".");
#>

# setup window
$window = $wpf.MWind
$window.Icon = $iconSource
$window.Title = $settings.general.windowTitle


################################################
#
# EVENTS
#
################################################

$browser.add_DocumentCompleted({
        #Write-Host $web.Url.AbsoluteUri
        $Global:uri = $browser.Url.AbsoluteUri        
        if ($Global:uri -match "error=[^&]*|code=[^&]*") {
            
            $queryOutput = [System.Web.HttpUtility]::ParseQueryString($browser.Url.Query)
    
            $output = @{}
            foreach($key in $queryOutput.Keys){
                $output["$key"] = $queryOutput[$key]
            }
            
            getAccessToken -resource $Global:resource
            $window.Hide()
            #$window.close()
            #Exit 0
            ExitWithCode -exitcode 0
        }
})


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

    $exitcode = 0

    $host.SetShouldExit($exitcode)    

    if ($settings.general.useApplicationContext -eq $true) {    
        #$window.exitCode = $exitcode
        [System.Environment]::ExitCode = 0
        #Return 0
        $Env:Errorlevel = 0
        [System.Windows.Forms.Application]::Exit()#; Stop-Process $pid
       
        #Environment.Exit(0)
    } else {
        exit $exitcode
    }
} 

# Function to popup Auth Dialog Windows Form for getting an AuthCode
function getAuthCode {
   
    $browser.Navigate($url -f ($Scope -join "%20"))     
    
    if ($settings.general.useApplicationContext -eq $true) {

        # Running this without $appContext and ::Run would actually cause a really poor response.
        $window.Show()
 
        # This makes it pop up
        $window.Activate()
 
        # Create an application context for it to all run within. 
        # This helps with responsiveness and threading.

        # Allow input to window for TextBoxes, etc
        [System.Windows.Forms.Integration.ElementHost]::EnableModelessKeyboardInterop($window)

        $appContext = New-Object System.Windows.Forms.ApplicationContext 
        [void][System.Windows.Forms.Application]::Run($appContext)

    } else {

        $window.ShowDialog() | Out-Null

    }
  
    

    #$output
}

function getAccessToken ($resource) {
    
    $parameter = [System.Web.HttpUtility]::ParseQueryString( ([System.Uri]$uri).Query )              
    $authCode  = $parameter["code"]

    Write-Host "Received an authCode, $authCode"

    #get Access Token
    $body = "grant_type=authorization_code&redirect_uri=$redirectUri&client_id=$clientId&client_secret=$clientSecretEncoded&code=$authCode&resource=$resource"
        
    Write-Host $body

    $Authorization = Invoke-RestMethod $tokenUri `
        -Method Post -ContentType "application/x-www-form-urlencoded" `
        -Body $body `
        -ErrorAction STOP
        
    Write-Host $authorization

    Write-Host "access token: $( $Authorization.access_token )"
    Write-Host "refresh token: $( $Authorization.refresh_token )"
    $Global:accesstoken = $Authorization.access_token
    $Global:refreshtoken = $Authorization.refresh_token 
    if ($refreshtoken) {
        $refreshtoken | out-file "$($refreshtokenpath)" -Force
    }
    $accesstoken | out-file "$($accesstokenpath)" -Force


    # Test API Call to get Current User

    $queryURL = $testUri

    if ($Authorization.token_type -eq "Bearer" ){
        Write-Host "You've successfully authenticated to $($resource) with authorization for $($Authorization.scope)"
        Write-Host "Test Query for authenticated user"
            
        # Test Query
        # Get the user who authenticated using this script
        $currentUser = Invoke-RestMethod -Method Get -Headers @{Authorization = "Bearer $accesstoken"
                                        'Content-Type' = 'application/json'} `
                            -Uri  $queryURL

        if ($currentUser) { Write-Host $currentUser } else { Write-Host "That's weird, the query failed. Check the error message." }

    } else{

        write-host "Check the console for errors. Chances are you provided the incorrect clientID and clientSecret combination for the API Endpoint selected"

    }

}


########################################################################
#                                                                      #
# PROCESS                                                              #
#                                                                      #
########################################################################


# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols

#AuthN
# Get Permissions (if the first time, get an AuthCode and Get a Bearer and Refresh Token
# Get AuthCode
$url = "$($authUri)?response_type=code&redirect_uri=$redirectUri&client_id=$clientID&resource=$resourceEncoded&scope=$scopeEncoded"
getAuthCode



