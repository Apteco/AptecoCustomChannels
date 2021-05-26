
################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true

$sendMailing = $true
$scheduleMailing = $false

#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
	    TransactionType= "Replace"
        Password= "gutentag"
        scriptPath= "C:\Users\NLethaus\Documents\2021\InxmailFlorian\Inxmail\Mailing"
        MessageName= "97 / Copy von VorlageVonNikolas240321"
        EmailFieldName= "email"
        SmsFieldName= ""
        Path= "C:\Users\NLethaus\Documents\2021\InxmailFlorian\Inxmail\Mailing\PowerShell_16  VorlageVonNikolas240321_2bad7cca-1922-4ace-8e48-252f9afb8c75.txt"
        ReplyToEmail= ""
        Username= "absdede"
        ReplyToSMS= ""
        UrnFieldName= "Kunden ID"
        ListName= "4 / testListe"
        CommunicationKeyFieldName= "Communication Key"

    }
}


################################################
#
# NOTES
#
################################################

<#

TODO [ ] implement more logging

#>

################################################
#
# SCRIPT ROOT
#
################################################

if ( $debug ) {
    # Load scriptpath
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    } else {
        $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    }
} else {
    $scriptPath = "$( $params.scriptPath )" 
}
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
#$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "INXBROADCAST"
#$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        #,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach-Object {
    . $_.FullName
    "... $( $_.FullName )"
}

# Load all exe files in subfolder
#$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
#$libExecutables | ForEach {
#    "... $( $_.FullName )"
#    
#}

# Load dll files in subfolder
#$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
#$libExecutables | ForEach {
#    "Loading $( $_.FullName )"
#    [Reflection.Assembly]::LoadFile($_.FullName) 
#}


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"

# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    $( $param ): $( $params[$param] )"
    }
}


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# AUTHENTICATION
#-----------------------------------------------

$apiRoot = $settings.base
$contentType = "application/hal+json"
$auth = "$( Get-SecureToPlaintext -String $settings.login.authenticationHeader )"
$header = @{
    "Authorization" = $auth
}

#-----------------------------------------------
# GET MAILING / LIST DETAILS 
#-----------------------------------------------

# Splitting MailingName and ListName to get Ids
$mailingIdArray = $params.MessageName.Split(" / ")
$listIdArray = $params.ListName.Split(" / ")

$mailingId = $mailingIdArray[0]
$listId = $listIdArray[0]

#-----------------------------------------------------------------
# COPY MAILING
#-----------------------------------------------------------------
$object = "operations"
$endpoint = "$( $apiRoot )$( $object )/mailings?command=copy"

$body = [Hashtable]@{
    mailingId = $mailingId
    listId = $listId
    copyApprovalState = $true
}

$bodyJson = $body | ConvertTo-Json

<#
    Copies the given mailing; this needs to be done in order to send it

    https://apidocs.inxmail.com/xpro/rest/v1/#copy-mailing
#>
$copiedMailing = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 
$copiedMailingId = $copiedMailing.id


#-----------------------------------------------------------------
# GET COPIED MAILING
#-----------------------------------------------------------------

$endpoint = "$( $apiRoot )/mailings/$( $copiedMailing.id )" #?embededded=inx:response-statistics,inx:sending-statistics"
<#
    https://apidocs.inxmail.com/xpro/rest/v1/#retrieve-single-regular-mailings
#>
$mailingsDetails = Invoke-RestMethod -Method Get -Uri $endpoint -Header $header -ContentType $contentType -Verbose




#-----------------------------------------------------------------
# SEND A MAILING 
#-----------------------------------------------------------------

if( $sendMailing ){
    $object = "sendings"
    $endpoint = "$( $apiRoot )$( $object )"
    $contentType = "application/json; charset=utf-8"
    
    $body = [hashtable]@{
        mailingId = $copiedMailingId
    }
    
    $bodyJson = $body | ConvertTo-Json
    
    <#
        Broadcasts the mailing to every given recipient instantly

        https://apidocs.inxmail.com/xpro/rest/v1/#_send_a_mailing_continue_sending_of_an_interrupted_sending
    #>
    $sentMailing = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 
    
}


#-----------------------------------------------------------------
# SCHEDULE MAILING / BROADCASTING
#-----------------------------------------------------------------

if( $scheduleMailing ){
    $object = "regular-mailings"
    $endpoint = "$( $apiRoot )$( $object )/$( $copiedMailingId )/schedule"
    # Time is in seconds
    $time = 10

    # Formating the Date to the correct format
    $date = (Get-Date).AddSeconds( $time ).ToString("yyyy-MM-ddTHH:mm:ss")
    $date2 = Get-Date -Format "ssK"
    $arr = $date2.Split(":")
    $arr2 = $arr[0].Split("+")
    $elem = $arr2[1]
    $elem = $elem + $arr[1]
    $elem = "+" + $elem
    $elem = $date + $elem
    $elem
    
    $body = [hashtable]@{
        scheduleDate = $elem # exampleFormat: "2022-04-22T13:29:57+0000"
    }
    
    $bodyJson = $body | ConvertTo-Json
    
    try{
        <#
            Broadcasts the mailing to every given recipient in $time seconds

            https://apidocs.inxmail.com/xpro/rest/v1/#schedule-regular-mailing
        #>
        $sentMailing = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 
    
    }catch{
        $e = ParseErrorForResponseBody($_)
        Write-Log -message ( $e | ConvertTo-Json -Depth 20 )
        throw $_.exception
    }
}



################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

$recipients = $null 

# put in the source id as the listname
$transactionId = $mailingId

# return object
$return = [Hashtable]@{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
}

# return the results
$return

