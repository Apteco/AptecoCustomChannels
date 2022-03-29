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
        TransactionType = 'Replace'
        Password = 'b'
        scriptPath = 'D:\Scripts\Syniverse\SyniverseSMS'
        MessageName = 'de587e1d-0eeb-4abe-ba9d-86125d7a935e | Willkommen SMS'
        EmailFieldName = ''
        SmsFieldName = 'mobile'
        Path = 'd:\faststats\Publish\Handel\system\Deliveries\PowerShell_de587e1d-0eeb-4abe-ba9d-86125d7a935e  Willkommen SMS_b8491988-947b-4646-a613-865c7ba95b3e.txt'
        ReplyToEmail = ''
        Username = 'a'
        ReplyToSMS = ''
        UrnFieldName = 'Kunden ID'
        ListName = 'de587e1d-0eeb-4abe-ba9d-86125d7a935e | Willkommen SMS'
        CommunicationKeyFieldName = 'Communication Key'        
    }
}


################################################
#
# NOTES
#
################################################

<#

#>

################################################
#
# SCRIPT ROOT
#
################################################

# if debug is on a local path by the person that is debugging will load
# else it will use the param (input) path
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

$script:moduleName = "SYNSMS-UPLOAD"

try {

    # Load general settings
    . ".\bin\general_settings.ps1"

    # Load settings
    . ".\bin\load_settings.ps1"

    # Load network settings
    . ".\bin\load_networksettings.ps1"

    # Load functions
    . ".\bin\load_functions.ps1"

    # Start logging
    . ".\bin\startup_logging.ps1"

    # Load preparation ($cred)
    . ".\bin\preparation.ps1"

} catch {

    Write-Log -message "Got exception during start phase" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ( [LogSeverity]::ERROR )
    
    throw $_.exception  

    exit 1

}



################################################
#
# PROGRAM
#
################################################


try {

    ################################################
    #
    # TRY
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

    Write-Log -message "Establishing connection to MSSQL database now"

    # define query
    $mssqlQuery = Get-Content -Path ".\sql\getmessages.sql" -Encoding UTF8

    # execute command
    $mssqlCommand = $mssqlConnection.CreateCommand()
    $mssqlCommand.CommandText = $mssqlQuery
    $mssqlResult = $mssqlCommand.ExecuteReader()
        
    # load data
    $mssqlTable = [System.Data.DataTable]::new()
    $mssqlTable.Load($mssqlResult)
        
    Write-Log -message "Loaded $( $mssqlTable.Rows.Count ) templates from MSSQL. Closing the database connection now"

    # Closing connection
    $mssqlConnection.Close()

    Write-Log -message "Connection closed"

    # Find the right template
    #$template = $mssqlTable | where { $_.Name -eq $params.MessageName }
    $template = @( $mssqlTable.Rows | where { $_.CreativeTemplateId -eq $chosenTemplate.mailingId } )

    # Check if there is only one template
    If ( $template.Count -eq 1 ) {
        Write-log -message "Found 1 template"
    } elseif ( $template.Count -gt 1 )  {
        $msg = "Too many templates found. Please check!"
        Write-Log -message $msg -severity ( [Logseverity]::ERROR )
        throw [System.IO.InvalidDataException] $msg
    } else {
        $msg = "No templates found. Please check!"
        Write-Log -message $msg -severity ( [Logseverity]::ERROR )
        throw [System.IO.InvalidDataException] $msg
    }


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
    #ping | Out-Null

    # Change the console output to UTF8
    #$originalConsoleCodePage = [Console]::OutputEncoding.CodePage
    #[Console]::OutputEncoding = [text.encoding]::utf8

    #$PSVersionTable | Out-File "D:\Scripts\Syniverse\SMS\test.txt"


    #-----------------------------------------------
    # DEFINE NUMBERS
    #-----------------------------------------------

    Write-Log -message "Loading input file '$( $params.Path )'"

    $data = @( Import-Csv -Path "$( $params.Path )" -Delimiter "`t" -Encoding UTF8 )
    #$data = get-content -path "$( $params.Path )" -encoding UTF8 -raw | ConvertFrom-Csv -Delimiter "`t"

    Write-Log -message "Loaded $( $data.Count ) records"


    #-----------------------------------------------
    # SINGLE SMS SEND
    #-----------------------------------------------

    Write-Log -message "Parsing data and putting links into syniverse functions via regex"

    # TODO [ ] check if mobile is populated

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
                "Urn" = $row."$( $params.UrnFieldName)"
                "CommunicationKey" = $row."$( $params.CommunicationKeyFieldName )"
            }
        )

    }

    Write-Log -message "Start to create a new file"

    # Filenames
    $tempFolder = "$( $uploadsFolder )\$( $processId.Guid )"
    New-Item -ItemType Directory -Path $tempFolder
    Write-Log -message "Creating files in $( $tempFolder )"
    $smsFile = "$( $tempFolder )\sms.csv"

    # Export parsed data
    $parsedData | Export-Csv -Path $smsFile -Encoding UTF8 -Delimiter "`t" -NoTypeInformation

    # Prepare api call
    $url = "$( $apiRoot )scg-external-api/api/v1/messaging/message_requests"

    # Set action when errors occur
    $defaultErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    # Loop through the data and POST the data to syniverse
    $results = [System.Collections.ArrayList]@()
    $errors = [System.Collections.ArrayList]@()
    $parsedData | ForEach {
        
        $parsedRow = $_
        $text = $_.message
        $mobile = $parsedRow.mdn
        
        switch ( $settings.sendMethod ) {

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
            "to"=[array]@( $mobile )
            #"media_urls"=@()
            #"attachments"=@()
            #"pause_before_transmit"=$false
            "verify_number"=$true
            "body"=$text #$smsTextTranslations.Item($mobileCountry)
            #"consent_requirement"="NONE"
        }
    
        If ( $debug -eq $true ) {
            Write-Log -message "SMS to: '$( $bodyContent.to )' with channel '$( $bodyContent.from )' and content '$( $bodyContent.body )'"
            #$res
        }
        
        try {

            $paramsPost = [Hashtable]@{
                Uri = $url
                Method = "Post"
                Headers = $headers
                Body = $bodyContent | ConvertTo-Json -Depth 99 -Compress
                Verbose = $true
                ContentType = $contentType
            }
            Check-Proxy -invokeParams $paramsPost

            <#
            if ( $settings.useDefaultCredentials ) {
                $paramsPost.Add("UseDefaultCredentials", $true)
            }
            if ( $settings.ProxyUseDefaultCredentials ) {
                $paramsPost.Add("ProxyUseDefaultCredentials", $true)
            }
            if ( $settings.proxyUrl ) {
                $paramsPost.Add("Proxy", $settings.proxyUrl)
            }
            #>

            $resRaw = Invoke-WebRequest @paramsPost
            #$res = [System.Text.encoding]::UTF8.GetString($resRaw.Content) | ConvertFrom-Json -Depth 99
            $res = ConvertFrom-Json -InputObject $resRaw.Content
            #$res = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -Verbose -ContentType $contentType # -UseDefaultCredentials -ProxyUseDefaultCredentials -Proxy $settings.proxyUrl
            
            If ( $debug -eq $true ) {
                Write-Log -message "SMS result: $( $res.id )"
            }

            # create new object with data
            [void]$results.Add(
                [PSCustomObject]@{
                    "messageid" = $res.id
                    "Urn" = $parsedRow.Urn
                    "CommunicationKey" = $parsedRow.CommunicationKey
                }
            )

        } catch {

            # Log the error and proceed
            #$res = [System.Text.encoding]::UTF8.GetString($resRaw.Content) | ConvertFrom-Json -Depth 99
            $e = ParseErrorForResponseBody -err $e
            Write-Log -message $e -severity ([LogSeverity]::ERROR)
            [void]$errors.Add(
                [PSCustomObject]@{
                    "messageid" = $res.id
                    "Urn" = $parsedRow.Urn
                    "CommunicationKey" = $parsedRow.CommunicationKey
                    "Error" = $e
                }
            )
            #[void]$errors.add( $e )

        }

    }

    # Setting erroractions back to default
    $ErrorActionPreference = $defaultErrorActionPreference

    # Write out the errors
    $errorfile = "$( $tempFolder )\errors.json"
    $errors | ConvertTo-Json -Depth 99 | Set-Content -Path $errorfile -Encoding UTF8

    # Log the results
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
    # INSERT ERRORED UPLOADS
    #
    ################################################

    # Adds entries to the database to show that those uploads have failed

    $updateResult = 0

    If ( $errors.Count -gt 0) {

        $mssqlConnection.Open()

        $errors | ForEach {

            $errorItem = $_

            # Prepare insert statement
            $insert = @"
            INSERT INTO [dbo].[Messages] ([service],[Urn],[BroadcastTransactionID],[MessageID],[CommunicationKey],[state])
            VALUES (
                'SYNSMS'
                ,'$( $errorItem.Urn )'
                ,'$( $processId.Guid )'
                ,'$( $errorItem.messageid )'
                ,'$( $errorItem.CommunicationKey )'
                ,'UPLOAD_FAILED'
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

        }

        # Commit the changes to sqlserver
        $messageUpdateMssqlCommand.Transaction.Commit()
        $mssqlConnection.Close()

    }

    Write-Log -message "Added $( $updateResult ) failed uploads to SQLServer"


    ################################################
    #
    # CHECK SENT STATUS AND INSERT IN MSSQL
    #
    ################################################

    Write-Log -message "Putting results in response database"

    If ( $results.Count -gt 0 ) {

        # open connection again
        $mssqlConnection.Open()
        $updateResult = 0

        # Initial wait of 15 seconds, so there is a good chance the messages are already "DELIVERED" OR "FAILED" instead of "SENT" (the state before...)
        $secondsToWait = $settings.firstResultWaitTime
        #$maxWaitTime = $settings.maxResultWaitTime

        # Loop for requesting the results
        $stopWatch = [System.Diagnostics.Stopwatch]::new()
        #$timeSpan = New-TimeSpan -Seconds $maxWaitTime 
        $stopWatch.Start()
        $states = [System.Collections.ArrayList]@()

        # Change the erroraction
        $ErrorActionPreference = 'Continue'

        # Go through all successful uploads
        #do {

        # Do the initial wait
        Start-Sleep -Seconds $secondsToWait

        # Prepare insert command and transaction
        $messageUpdateMssqlCommand = $mssqlConnection.CreateCommand()
        $messageUpdateMssqlCommand.Transaction = $mssqlConnection.BeginTransaction() # TODO [ ] maybe commit in between

        # Go through the single results
        $queue = [System.Collections.ArrayList]@()
        $queue.AddRange($results)
        $requestCounter = 0
        Do {

            # Get always the first item
            $queueItem = $queue[0]

            # Get the status via REST API
            try {

                # Prepare the payload
                $paramsGet = [Hashtable]@{
                    Uri = "$( $settings.base )scg-external-api/api/v1/messaging/message_requests/$( $queueItem.messageid )"
                    Method = "Get"
                    Headers = $headers
                    Verbose = $true
                    ContentType = $contentType                    
                }
                Check-Proxy -invokeParams $paramsGet        

                # Request the API
                $messageStatusRaw = Invoke-WebRequest @paramsGet
                $messageStatusRawContent = Convert-StringEncoding $messageStatusRaw.Content -inputEncoding ([System.Text.Encoding]::Default.HeaderName) -outputEncoding ([System.Text.Encoding]::UTF8.HeaderName)
                $messageStatus = ConvertFrom-Json -InputObject $messageStatusRawContent
                
            } catch {
                
                # When getting a 404, the script will retry again until the timeout occurs
                # TODO [ ] not sure if this is the right approach to resolve the error  
                #$messageStatus = [System.Text.encoding]::UTF8.GetString( $_ ) | ConvertFrom-Json -Depth 99              
                $e = ParseErrorForResponseBody -err $_
                Write-Log -message "Error happened during status request at syniverse" -severity ([LogSeverity]::WARNING)
                Write-Log -message $e

            }

            # Remove the item anyway from first position
            $queue.RemoveAt(0)
            $requestCounter += 1

            # This means the call was successful
            If ( $messageStatusRaw.StatusCode -eq 200 -and $messageStatus.state -in $successStates ) {

                [void]$states.Add( $messageStatus )

                # Prepare insert statement
                $insert = @"
                INSERT INTO [dbo].[Messages] ([service],[Urn],[BroadcastTransactionID],[MessageID],[CommunicationKey],[failurecode],[state],[to])
                VALUES (
                    'SYNSMS'
                    ,'$( $queueItem.Urn )'
                    ,'$( $processId.Guid )'
                    ,'$( $queueItem.messageid )'
                    ,'$( $queueItem.CommunicationKey )'
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

            } else {

                # Put at the end if not successful            
                [void]$queue.Add( $queueItem )
                
            }

            # Asking for the status of the requests, but one item could be asked for multiple times
            If ( $requestCounter % $mod -eq 0 ) { # TODO [ ] put this into settings or somewhere else
                Write-Log -message "Done $( $requestCounter ) requests - $( $queue.Count ) items remaining"
                $messageUpdateMssqlCommand.Transaction.Commit()
                $messageUpdateMssqlCommand.Transaction = $mssqlConnection.BeginTransaction()
            }

            # Make a pause if reaching a limit
            If ( ($requestCounter - 1) % ($results.Count + 1) -eq 0 ) {
                Write-Log -message "Doing a pause of $( $secondsToWait  ) seconds"
                Start-Sleep -Seconds $secondsToWait                
            }

        } until ( $queue.count -eq 0 )

        # Commit the changes to sqlserver if transaction exists - should always be the case
        If ( $messageUpdateMssqlCommand.Transaction ) {
            $messageUpdateMssqlCommand.Transaction.Commit()
        }
        $mssqlConnection.Close()
        $stopWatch.Stop()

    }


        #$results | where { $_.messageid -notin $states.id } | ForEach {
            
            #$result = $_

            # Get message requests result and save it into SQL, if possible
            #try {

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
<#
                $paramsGet = [Hashtable]@{
                    Uri = "$( $settings.base )scg-external-api/api/v1/messaging/message_requests/$( $result.messageid )"
                    Method = "Get"
                    Headers = $headers
                    Verbose = $true
                    ContentType = $contentType
                }
                #>
                <#
                if ( $settings.useDefaultCredentials ) {
                    $paramsGet.Add("UseDefaultCredentials", $true)
                }
                if ( $settings.ProxyUseDefaultCredentials ) {
                    $paramsGet.Add("ProxyUseDefaultCredentials", $true)
                }
                if ( $settings.proxyUrl ) {
                    $paramsGet.Add("Proxy", $settings.proxyUrl)
                }#>
                <#
                Check-Proxy -invokeParams $paramsGet
        
                $messageStatusRaw = Invoke-WebRequest @paramsGet
                $messageStatus = [System.Text.encoding]::UTF8.GetString($messageStatusRaw.Content) | ConvertFrom-Json -Depth 99
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
#>
                <#
                When getting a 404, the script will retry again until the timeout occurs
                #>
                <#
                $e = ParseErrorForResponseBody -err $_
                Write-Log -message "Error happened during status request at syniverse" -severity ([LogSeverity]::ERROR)
                Write-Log -message $e

            }        # TODO [ ] Only add to array and to database, if it wasn't a 404 

        }

        # Commit the changes to sqlserver
        $messageUpdateMssqlCommand.Transaction.Commit()
        #$messageUpdateMssqlCommand.Transaction.Rollback()

    } until (( $stopWatch.Elapsed -ge $timeSpan -or $results.count -eq $states.Count)) # until (( $sends.Count -eq $sendsStatus.count ) -or ( $stopWatch.Elapsed -ge $timeSpan ))
#>
    # Setting erroractions back to default
    $ErrorActionPreference = $defaultErrorActionPreference


    # Insert all entries without a status that was given back in time
    # Prepare insert command and transaction
    <#
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
    #>
    #$mssqlConnection.Close()

    # Logging
    Write-Log -message "Sent out $( $results.Count ) SMS"
    Write-Log -message "Written $( $updateResult ) records to SQLServer"
    Write-Log -message "Got message status back from $( $states.Count ) messages, in detail:"
    $states.state | group | foreach {
        Write-Log -message "    $( $_.Name ): $( $_.Count )"
    }
    Write-Log -message "Needed $( [math]::Round($stopwatch.Elapsed.TotalMinutes,2) ) minutes and $( $requestCounter ) requests for checking the status of $( $results.Count ) SMS"

} catch {

    ################################################
    #
    # ERROR HANDLING
    #
    ################################################

    Write-Log -message "Got exception during execution phase" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ( [LogSeverity]::ERROR )
    
    throw $_.exception

} finally {

    ################################################
    #
    # RETURN
    #
    ################################################

    #-----------------------------------------------
    # RETURN VALUES TO PEOPLESTAGE
    #-----------------------------------------------

    # count the number of successful upload rows
    $recipients = ( $states | where { $_.state -in $successStates } ).count #$results.count # ( $importResults | where { $_.Result -eq 0 } ).count
    
    # put in the source id as the listname
    $transactionId = $processId.Guid #$recipientListID
    
    # return object
    $return = [Hashtable]@{
    
         # Mandatory return values
         "Recipients"=$recipients
         "TransactionId"=$transactionId
    
         # General return value to identify this custom channel in the broadcasts detail tables
         "CustomProvider"=$moduleName
         "ProcessId" = $transactionId
    
         # Some more information for the broadcasts script
         "SMSFieldName"= $params.SmsFieldName
         "Path"= $params.Path
         "UrnFieldName"= $params.UrnFieldName
         
         # More information about the different status of the import
         "RecipientsIgnored" = $errors.Count
         "RecipientsQueued" = $results.Count
         "RecipientsSent" = $recipients
         "RecipientsFailed" = ( $states | where { $_.state -notin $successStates } ).count
    
    }

    # log the return object
    Write-Log -message "RETURN:"
    $return.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    $( $param ) = '$( $return[$param] )'" -writeToHostToo $false
    }
    
    
    # return the results
    $return

}

