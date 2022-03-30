

#-----------------------------------------------
# REST AUTHENTICATION
#-----------------------------------------------

$apiRoot = $settings.base
$headers = @{
    "Authorization"= "Bearer $( Get-SecureToPlaintext -String $settings.authentication.accessToken )"
}
$contentType = "application/json; charset=utf-8"


#-----------------------------------------------
# DATABASE SETTINGS
#-----------------------------------------------

$mssqlConnectionString = $settings.responseDB


#-----------------------------------------------
# MORE SETTINGS
#-----------------------------------------------

if ( $settings.rowsPerUpload ) {
    $maxWriteCount = $settings.rowsPerUpload
} else {
    $maxWriteCount = 100
}

$successStates = @('DELIVERED', 'FAILED', 'CLICKTHRU') # took out SENT because DELIVERED and FAILED or optionally CLICKTHRU will follow on those

# Setting how often the status should be written to the log
$mod = 200


#-----------------------------------------------
# CHECK FOLDERS
#-----------------------------------------------

$uploadsFolder = $settings.uploadsFolder
if ( !(Test-Path -Path "$( $uploadsFolder )") ) {
    Write-Log -message "Upload '$( $uploadsFolder )' does not exist. Creating the folder now!"
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}


#-----------------------------------------------
# REGEX PATTERNS
#-----------------------------------------------

$regexForValuesBetweenCurlyBrackets = "(?<={{)(.*?)(?=}})"
$regexForLinks = "(http[s]?)(:\/\/)({{(.*?)}}|[^\s,])+"