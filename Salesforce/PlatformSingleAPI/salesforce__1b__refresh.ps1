Param (
    #$test
)

################################################
#
# TODO
#
################################################

# TODO [ ] bla böa



################################################
#
# LINKS
#
################################################

<#



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


# Load more assemblies for WPF
Add-Type -AssemblyName System.Web




########################################################################
#                                                                      #
# SETTINGS                                                             #
#                                                                      #
########################################################################


#The resource URI
#$resource = $settings.salesforce.uri.resource
#$authUri = $settings.salesforce.uri.authUri
$tokenUri = $settings.salesforce.uri.tokenUri
#$testUri = $settings.salesforce.uri.testUri

#Your Client ID and Client Secret obainted when registering your WebApp
$clientid = $settings.salesforce.authentication.clientid
$clientSecret = $settings.salesforce.authentication.clientSecret

#Your Reply URL configured when registering your WebApp
$redirectUri = $settings.salesforce.uri.redirectUri

#Scope
#$scope = $settings.salesforce.authentication.scope

#UrlEncode the ClientID and ClientSecret and URL's for special characters
#$clientIDEncoded = [System.Web.HttpUtility]::UrlEncode($clientid)
$clientSecretEncoded = [System.Web.HttpUtility]::UrlEncode($clientSecret)
#$resourceEncoded = [System.Web.HttpUtility]::UrlEncode($resource)
#$scopeEncoded = [System.Web.HttpUtility]::UrlEncode($scope)

#Refresh Token Path
$refreshtokenpath = "$( $scriptPath )\refresh.token"
$accesstokenpath = "$( $scriptPath )\access.token"




########################################################################
#                                                                      #
# FUNCTIONS                                                            #
#                                                                      #
########################################################################


function getNewToken  {

    # We have a previous refresh token. 
    # use it to get a new token

    $refreshtoken = Get-Content "$($refreshtokenpath)"
    # Refresh the token
    #get Access Token
    $body = "grant_type=refresh_token&refresh_token=$refreshtoken&redirect_uri=$redirectUri&client_id=$clientId&client_secret=$clientSecretEncoded"
    $Global:Authorization = Invoke-RestMethod  $tokenUri `
        -Method Post -ContentType "application/x-www-form-urlencoded" `
        -Body $body `
        -ErrorAction STOP

    $Global:accesstoken = $Authorization.access_token
    $Global:refreshtoken = $Authorization.refresh_token

    if ($refreshtoken){
        $refreshtoken | out-file "$($refreshtokenpath)"
        $accesstoken | out-file "$($accesstokenpath)"    
        write-host "Updated tokens" 
        $Authorization    
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

#Test Refreshing our token
getNewToken
