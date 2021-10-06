
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

$headers = @{
    "Cookie" = "$( $login.session_name )=$( $login.sessid )"
    #"Accept" = $contentType
}

$modeList = [ArrayList]@(
    @{
        id = 1
        name = "subscribe"
    }
    @{
        id = 1
        name = "unsubscribe"
    }
)