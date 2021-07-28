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

$debug = $false


#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
        "TransactionType"="Replace"
        "Password"="b"
        "scriptPath"="D:\Scripts\Syniverse\SMS"
        "MessageName"="SMS Wallet Offer"
        "EmailFieldName"="Email"
        "SmsFieldName"="mdn"
        "Path"="d:\faststats\Publish\Handel\system\Deliveries\PowerShell_SMS Wallet Offer_2aa41347-0c0a-43ae-987c-dc7210ba9281.txt"
        "ReplyToEmail"=""
        "Username"="a"
        "ReplyToSMS"=""
        "UrnFieldName"="Kunden ID"
        "ListName"="SMS Wallet Offer"
        "CommunicationKeyFieldName"="Communication Key"
    }
}

################################################
#
# NOTES
#
################################################

<#

https://github.com/Syniverse/QuickStart-BatchNumberLookup-Python/blob/master/ABA-example-external.py

FILEUPLOAD UP TO 2 GB allowed

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
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "SYNSMSUPLOAD"
$processId = [guid]::NewGuid()
$timestamp = [datetime]::Now.ToString("yyyyMMddHHmmss")

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
if ( $settings.rowsPerUpload ) {
    $maxWriteCount = $settings.rowsPerUpload
} else {
    $maxWriteCount = 100
}
$uploadsFolder = $settings.uploadsFolder
$mssqlConnectionString = $settings.responseDB

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

Add-Type -AssemblyName System.Data #, System.Web  #, System.Text.Encoding

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}
<#
# Load all exe files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
    
}

# Load dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
$libExecutables | ForEach {
    "Loading $( $_.FullName )"
    [Reflection.Assembly]::LoadFile($_.FullName) 
}
#>


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $moduleName )"
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
        Write-Log -message "    $( $param )= ""$( $params[$param] )"""
    }
}


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# READ TEMPLATE
#-----------------------------------------------


$chosenTemplate = [Mailing]::new($params.MessageName)

Write-Log -message "Loading template with name $( $params.MessageName )"

$mssqlConnection = [System.Data.SqlClient.SqlConnection]::new()
$mssqlConnection.ConnectionString = $mssqlConnectionString

$mssqlConnection.Open()

"Trying to load the data from MSSQL"

# define query
$mssqlQuery = Get-Content -Path ".\sql\getmessages.sql" -Encoding UTF8

# execute command
$mssqlCommand = $mssqlConnection.CreateCommand()
$mssqlCommand.CommandText = $mssqlQuery
$mssqlResult = $mssqlCommand.ExecuteReader()
    
# load data
$mssqlTable = [System.Data.DataTable]::new()
$mssqlTable.Load($mssqlResult)
    
# Closing connection
$mssqlConnection.Close()

# Find the right template
#$template = $mssqlTable | where { $_.Name -eq $params.MessageName }
$template = $mssqlTable | where { $_.CreativeTemplateId -eq $chosenTemplate.mailingId }


#-----------------------------------------------
# REGEX FOR EXTRACT OF LINKS AND TOKENS IN TEMPLATE
#-----------------------------------------------

<#
# some notes and other way for selections
# https://www.regextester.com/97589
$hash=@{}
$creativeTemplateText | select-string -AllMatches '(http[s]?)(:\/\/)([^\s,]+)' | %{ $hash."Valid URLs"=$_.Matches.value }
$hash
#>

# Regex patterns
$regexForValuesBetweenCurlyBrackets = "(?<={{)(.*?)(?=}})"
$regexForLinks = "(http[s]?)(:\/\/)({{(.*?)}}|[^\s,])+"

# extract the important template information
# https://stackoverflow.com/questions/34212731/powershell-get-all-strings-between-curly-braces-in-a-file
$creativeTemplateText = $template.Creative
$creativeTemplateToken = [Regex]::Matches($creativeTemplateText, $regexForValuesBetweenCurlyBrackets) | Select -ExpandProperty Value
$creativeTemplateLinks = [Regex]::Matches($creativeTemplateText, $regexForLinks) | Select -ExpandProperty Value

Write-Log -message "Found $( $creativeTemplateToken.count ) tokens to replace in the template:"
$creativeTemplateToken | ForEach { Write-Log -message "  $( $_ )" }
Write-Log -message "Found $( $creativeTemplateLinks.count ) links to parse in the template:"
$creativeTemplateLinks | ForEach { Write-Log -message "  $( $_ )" }



#-----------------------------------------------
# SWITCH TO UTF8
#-----------------------------------------------
# Call an external program first so the console encoding command works in ISE, too. Good explanation here: https://social.technet.microsoft.com/Forums/scriptcenter/en-US/b92b15c8-6854-4d3e-8a35-51b4b56276ba/powershell-ise-vs-consoleoutputencoding?forum=ITCG
ping | Out-Null

# Change the console output to UTF8
$originalConsoleCodePage = [Console]::OutputEncoding.CodePage
[Console]::OutputEncoding = [text.encoding]::utf8

#$PSVersionTable | Out-File "D:\Scripts\Syniverse\SMS\test.txt"


#-----------------------------------------------
# DEFINE NUMBERS
#-----------------------------------------------

Write-Log -message "Loading input file"

# TODO [ ] use split file process for larger files
# TODO [ ] load parameters from creative template for default values

#$data = Import-Csv -Path "$( $params.Path )" -Delimiter "`t" -Encoding UTF8
$data = get-content -path "$( $params.Path )" -encoding UTF8 -raw | ConvertFrom-Csv -Delimiter "`t"


#-----------------------------------------------
# PREPARE HEADERS
#-----------------------------------------------

$headers = @{
    "Authorization"= "Bearer $( Get-SecureToPlaintext -String $settings.authentication.accessToken )"
}
$contentType = "application/json; charset=utf-8"


#-----------------------------------------------
# SINGLE SMS SEND
#-----------------------------------------------

# TODO [ ] put this workflow in parallel groups
Write-Log -message "Parsing data and putting links into syniverse functions via regex"

$parsedData = [System.Collections.ArrayList]@()
$data | ForEach {

    $row = $_
    $txt = $creativeTemplateText
    
    # replace all tokens in links in text with personalised data
    $creativeTemplateLinks | ForEach {
        $linkTemplate = $_
        $linkReplaced = $_
        $creativeTemplateToken | ForEach {
            $token = $_
            $linkReplaced = $linkReplaced -replace [regex]::Escape("{{$( $token )}}"), [uri]::EscapeDataString($row.$token)
            #Write-Log -message "$( ($row.$token).toString() ) - $( [uri]::EscapeDataString($row.$token) )"
        }
        # the #track function in syniverse automatically creates a trackable short link in the SMS
        $txt = $txt -replace [regex]::Escape($linkTemplate), "#track(""$( $linkReplaced )"")"
    }    

    # replace all remaining tokens in text with personalised data
    $creativeTemplateToken | ForEach {
        $token = $_
        $txt = $txt -replace [regex]::Escape("{{$( $token )}}"), $row.$token
    }

    # Unescape and escape data to catch remaining umlauts in the template
    #$txt = [uri]::EscapeDataString([uri]::UnescapeDataString($txt))
    
    # add to array
    [void]$parsedData.Add(
        [PSCustomObject]@{
            "mdn" = $row."$( $params.SmsFieldName )"
            "message" = $txt
            "Urn" = $row.($params.UrnFieldName)
            "CommunicationKey" = $row.($params.CommunicationKeyFieldName)
        }
    )

}

Write-Log -message "Start to create a new file"

# create new guid
$smsId = $processId.Guid

# Filenames
$tempFolder = "$( $uploadsFolder )\$( $smsId )"
New-Item -ItemType Directory -Path $tempFolder
Write-Log -message "Creating files in $( $tempFolder )"
$smsFile = "$( $tempFolder )\sms.csv"

$parsedData | Export-Csv -Path $smsFile -Encoding UTF8 -Delimiter "`t" -NoTypeInformation

$url = "$( $settings.base )scg-external-api/api/v1/messaging/message_requests"

$results = [System.Collections.ArrayList]@()
$errors = [System.Collections.ArrayList]@()
$parsedData | ForEach {
    
    $parsedRow = $_
    $text = $_.message
    $mobile = $parsedRow.mdn
    
    switch ($settings.sendMethod) {
        "sender_id" {
            $sendFrom = $settings.senderId
        }
        "channel" {
            $mobileCountry = $settings.countryMap.($mobile.Substring(0,3))
            $sendFrom = $settings.channels.($mobileCountry)
        }
    }

    $bodyContent = @{
        "from"="$( $settings.sendMethod ):$( $sendFrom )"
        "to"=@($mobile)
        #"media_urls"=@()
        #"attachments"=@()
        #"pause_before_transmit"=$false
        "verify_number"=$true
        "body"=$text #$smsTextTranslations.Item($mobileCountry)
        #"consent_requirement"="NONE"
    }
   

    Write-Log -message "SMS to: '$( $bodyContent.to )' with channel '$( $bodyContent.from )' and content '$( $bodyContent.body )'"
    #$res

    $body = $bodyContent | ConvertTo-Json -Depth 8 -Compress
    #$body

    try {

        $paramsPost = [Hashtable]@{
            Uri = $url
            Method = "Post"
            Headers = $headers
            Body = $body
            Verbose = $true
            ContentType = $contentType
        }

        if ( $settings.useDefaultCredentials ) {
            $paramsPost.Add("UseDefaultCredentials", $true)
        }
        if ( $settings.ProxyUseDefaultCredentials ) {
            $paramsPost.Add("ProxyUseDefaultCredentials", $true)
        }
        if ( $settings.proxyUrl ) {
            $paramsPost.Add("Proxy", $settings.proxyUrl)
        }

        $res = Invoke-RestMethod @paramsPost
        #$res = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -Verbose -ContentType $contentType # -UseDefaultCredentials -ProxyUseDefaultCredentials -Proxy $settings.proxyUrl

        Write-Log -message "SMS result: $( $res.id )"

        # create new object with data
        [void]$results.Add(
            [PSCustomObject]@{
                "messageid" = $res.id
                "Urn" = $parsedRow.Urn
                "CommunicationKey" = $parsedRow.CommunicationKey
            }
        )

    } catch {

        $e = ParseErrorForResponseBody -err $_
        Write-Log -message $e -severity ([LogSeverity]::ERROR)
        [void]$errors.add( $e )

    }

}

# Logging
$errorfile = "$( $tempFolder )\errors.json"
$errors | ConvertTo-Json -Depth 20 | Set-Content -Path $errorfile -Encoding UTF8

Write-Log -message "Successful http requests: $( $results.count )"
If ( $errors.Count -gt 0 ) {
    Write-Log -message "Errored http requests: $( $errors.count )" -severity ([LogSeverity]::WARNING)
    Write-Log -message "Errors written into file '$( $errorfile )'"
} else {
    Write-Log -message "Errored http requests: $( $errors.count )" -severity ([LogSeverity]::INFO)
}

# If nothing was successful, just throw an exception
If ( $results.count -eq 0 ) {
    Write-Log -message "No successful records were uploaded, throwing exception" -severity ([LogSeverity]::ERROR)
    throw [System.IO.InvalidDataException] "No successful records were uploaded"
}


################################################
#
# INSERT COMMUNICATION KEY IN MSSQL
#
################################################

Write-Log -message "Putting results in response database"

# open connection again
$mssqlConnection.Open()
$updateResult = 0

# Initial wait of 15 seconds, so there is a good chance the messages are already "DELIVERED" OR "FAILED" instead of "SENT" (the state before...)
$secondsToWait = $settings.firstResultWaitTime
$maxWaitTime = $settings.maxResultWaitTime

# Loop for requesting the results
$stopWatch = [System.Diagnostics.Stopwatch]::new()
$timeSpan = New-TimeSpan -Seconds $maxWaitTime 
$stopWatch.Start()
$states = [System.Collections.ArrayList]@()

do {

    Start-Sleep -Seconds $secondsToWait

    # Prepare insert command and transaction
    $messageUpdateMssqlCommand = $mssqlConnection.CreateCommand()
    $messageUpdateMssqlCommand.Transaction = $mssqlConnection.BeginTransaction()

    # Go through the single results
    $results | where { $_.messageid -notin $states.id } | ForEach {
        
        $result = $_

        # Get message requests result and save it into SQL, if possible
        try {

            <#
            
            Getting a response like, where the state can be SENT, DELIVERED, FAILED, CLICKTHROUGH
            
            application_id                    : 1234
            company_id                        : 9999
            created_date                      : 1619433193844
            last_updated_date                 : 1619433201381
            version_number                    : 3
            id                                : J8Y6XuvoGGf3xxxxxxxxxx
            from                              : channel:JXxaP5zxxxxxxxxxxxxxx
            to                                : {+4917664787187}
            consent_requirement               : NONE
            body                              : Florian, thanks for adding your mobile number to your profile. Get your 10% discount now: https://2.lnkme.net/H5eoSp
            state                             : DELIVERED
            channel_id                        : JXxaP5zxxxxxxxxxxxxxx
            sender_id_sort_criteria           : {}
            contact_delivery_address_priority : {}
            verify_number                     : False
            message_type                      : SMS

            OR 

            application_id                    : 1234
            company_id                        : 9999
            created_date                      : 1619458867858
            last_updated_date                 : 1619458869321
            version_number                    : 2
            id                                : L8P0wENVG31Fxxxxxxxxxx
            from                              : channel:JXxaP5zxxxxxxxxxxxxxx
            to                                : {+4927664787187}
            consent_requirement               : NONE
            body                              : Florian, thanks for adding your mobile number to your profile. Get your 10% discount now: https://2.lnkme.net/bbfs8u
            state                             : FAILED
            failure_code                      : 1002
            failure_details                   : Invalid recipient +4927664787187 for message L8P0wENVG31Fxxxxxxxxxx
            channel_id                        : JXxaP5zxxxxxxxxxxxxxx
            sender_id_sort_criteria           : {}
            contact_delivery_address_priority : {}
            verify_number                     : True
            message_type                      : SMS

            #>

            $paramsGet = [Hashtable]@{
                Uri = "$( $settings.base )scg-external-api/api/v1/messaging/message_requests/$( $result.messageid )"
                Method = "Get"
                Headers = $headers
                Verbose = $true
                ContentType = $contentType
            }
    
            if ( $settings.useDefaultCredentials ) {
                $paramsGet.Add("UseDefaultCredentials", $true)
            }
            if ( $settings.ProxyUseDefaultCredentials ) {
                $paramsGet.Add("ProxyUseDefaultCredentials", $true)
            }
            if ( $settings.proxyUrl ) {
                $paramsGet.Add("Proxy", $settings.proxyUrl)
            }
    
            $messageStatus = Invoke-RestMethod @paramsGet
            #$messageStatus = Invoke-RestMethod -Uri "https://api.syniverse.com/scg-external-api/api/v1/messaging/message_requests/$( $result.messageid )" -Method Get -Headers $headers -Verbose -ContentType $contentType #-UseDefaultCredentials -Proxy $ProxyURL -ProxyUseDefaultCredentials
            
            #$messageStatus
            [void]$states.Add( $messageStatus )

            # Prepare insert statement
            $insert = @"
            INSERT INTO [dbo].[Messages] ([service],[Urn],[BroadcastTransactionID],[MessageID],[CommunicationKey],[failurecode],[state],[to])
            VALUES (
                'SYNSMS'
                ,'$( $result.Urn )'
                ,'$( $processId.Guid )'
                ,'$( $result.messageid )'
                ,'$( $result.CommunicationKey )'
                ,'$( $messageStatus.failure_code )'
                ,'$( $messageStatus.state )'
                ,'$( $messageStatus.to )'
                )
"@
            # Add it to sqlserver table
            try {

                # execute command
                $messageUpdateMssqlCommand.CommandText = $insert
                $updateResult += $messageUpdateMssqlCommand.ExecuteNonQuery()
            
            } catch [System.Exception] {

                $errText = $_.Exception
                $errText | Write-Output
                Write-Log -message "Error happened during insert on sqlserver" -severity ([LogSeverity]::ERROR)
                Write-Log -message $errText -severity ([LogSeverity]::ERROR)

            } finally {

            }

        } catch {

            <#
            When getting a 404, the script will retry again until the timeout occurs
            #>
            $e = ParseErrorForResponseBody -err $_
            Write-Log -message "Error happened during status request at syniverse" -severity ([LogSeverity]::ERROR)
            Write-Log -message $e

        }        # TODO [ ] Only add to array and to database, if it wasn't a 404 

    }

    # Commit the changes to sqlserver
    $messageUpdateMssqlCommand.Transaction.Commit()
    #$messageUpdateMssqlCommand.Transaction.Rollback()

} until (( $stopWatch.Elapsed -ge $timeSpan -or $results.count -eq $states.Count)) # until (( $sends.Count -eq $sendsStatus.count ) -or ( $stopWatch.Elapsed -ge $timeSpan ))


# Insert all entries without a status that was given back in time
# Prepare insert command and transaction
$messageUpdateMssqlCommand = $mssqlConnection.CreateCommand()
$messageUpdateMssqlCommand.Transaction = $mssqlConnection.BeginTransaction()
$results | where { $_.messageid -notin $states.id } | ForEach {
        
    $result = $_

    # Prepare insert statement
    $insert = @"
    INSERT INTO [dbo].[Messages] ([service],[Urn],[BroadcastTransactionID],[MessageID],[CommunicationKey])
    VALUES (
        'SYNSMS'
        ,'$( $result.Urn )'
        ,'$( $processId.Guid )'
        ,'$( $result.messageid )'
        ,'$( $result.CommunicationKey )'
        )
"@

    # execute command
    $messageUpdateMssqlCommand.CommandText = $insert
    $updateResult += $messageUpdateMssqlCommand.ExecuteScalar() #$mssqlCommand.ExecuteNonQuery()

}

# Commit the last transaction and close the connection
$messageUpdateMssqlCommand.Transaction.Commit()
$mssqlConnection.Close()

# Logging
Write-Log -message "Sent out $( $results.Count ) SMS"
Write-Log -message "Written $( $updateResult ) records to SQLServer"
Write-Log -message "Got message status back from $( $states.Count ) messages, in detail:"
$states.state | group | foreach {
    Write-Log -message "    $( $_.Name ): $( $_.Count )"
}


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

<#

JUST FORWARDING A FEW PARAMETERS TO THE BROADCAST TO DO EVERYTHING THERE

#>

Write-Log -message "Just forwarding parameters to broadcast"


# TODO [ ] check return results

# count the number of successful upload rows
$recipients = ($states | where { $_.state -eq "SUCCESS" }).count #$results.count # ( $importResults | where { $_.Result -eq 0 } ).count

# There is no id reference, but saving and using the current GUI, that will be saved in the broadcastdetails
$transactionId = $processId.Guid #$recipientListID

# return object
$return = [Hashtable]@{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
    "CustomProvider"=$moduleName
    "ProcessId" = $processId.Guid
    #"EmailFieldName"= $params.EmailFieldName
    "SMSFieldName"= $params.SmsFieldName
    "Path"= $params.Path
    "UrnFieldName"= $params.UrnFieldName
}

# return the results
$return