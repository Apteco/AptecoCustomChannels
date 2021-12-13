
#-----------------------------------------------
# DO THE FIRST LOGIN
#-----------------------------------------------


$restParams = @{
    "Method" = "Post"
    "Uri" = "$( $settings.base )/account/login.json"
    "ContentType" = $settings.contentType
    "Headers" = $headers
    "Verbose" = $true
    "Body" = @{
        username= $settings.authentication.username
        password = Get-SecureToPlaintext -string $settings.authentication.password
    } | ConvertTo-Json -Depth 99
}

$login = Invoke-RestMethod @restParams


#-----------------------------------------------
# BUILD THE COOKIE OBJECT
#-----------------------------------------------

$uri = [uri]($restParams.uri)

$Cookie = [System.Net.Cookie]::new()
$Cookie.Name = $login.session_name # Add the name of the cookie
$Cookie.Value = $login.sessid # Add the value of the cookie
$Cookie.Domain = $uri.DnsSafeHost

$WebSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
$WebSession.Cookies.Add($Cookie)


#-----------------------------------------------
# BUILD THE DEFAULT REST PARAMS
#-----------------------------------------------

$headers = [Hashtable]@{
    #"Cookie" = "$( $login.session_name )=$( $login.sessid )" # alternative usage, but does not work with 5.1, but with PS7
    #"Accept" = $settings.contentType
    #"Host" = "api.klicktipp.com"
}

$defaultRestParams = @{
    "Websession" = $WebSession
    "ContentType" = $settings.contentType
    "Headers" = $headers
    #"Verbose" = $true
}


#-----------------------------------------------
# DEFAULT ACTIONS FOR SCRIPT
#-----------------------------------------------

$modeList = @(
    [PSCustomObject]@{
        id = 10
        name = "subscribe"
    }
    [PSCustomObject]@{
        id = 20
        name = "update"
    }
    [PSCustomObject]@{
        id = 30
        name = "unsubscribe"
    }
    [PSCustomObject]@{
        id = 40
        name = "delete"
    }
)