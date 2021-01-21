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


#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
        "TransactionType" = "Replace"
        "Password" = "b"
        "scriptPath" = "D:\Scripts\ELAINE\Transactional"
        "MessageName" = "1875 / Apteco PeopleStage Training Automation"
        "EmailFieldName" = "c_email"
        "SmsFieldName" = ""
        "Path" = "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\ELAINE\Transactional\PowerShell_1875  Apteco PeopleStage Training Automation_272d3042-885e-4191-bea8-6d1a54f3bb3f.txt"
        "ReplyToEmail" = ""
        "Username" = "a"
        "ReplyToSMS" = ""
        "UrnFieldName" = "Kunden ID"
        "ListName" = "1935 / FERGETestInitialList-20210120-100246"
        "CommunicationKeyFieldName" = "Communication Key"
    }
}

################################################
#
# NOTES
#
################################################

<#

TODO [ ] How to work with multilingual variants?


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
$moduleName = "ELNUPLOAD"
$processId = [guid]::NewGuid()

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
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments:"
[Environment]::GetCommandLineArgs() | ForEach {
    Write-Log -message "    $( $_ -replace "`r|`n",'' )"
}
# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    Write-Log -message "Got these params object:"
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    ""$( $param )"" = ""$( $params[$param] )"""
    }
}


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# CHECK RESULTS FOLDER
#-----------------------------------------------
<#
$uploadsFolder = $settings.upload.uploadsFolder
if ( !(Test-Path -Path $uploadsFolder) ) {
    Write-Log -message "Upload $( $uploadsFolder ) does not exist. Creating the folder now!"
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}
#>

#-----------------------------------------------
# PREPARE CALLING ELAINE
#-----------------------------------------------

Create-ELAINE-Parameters


#-----------------------------------------------
# ELAINE VERSION
#-----------------------------------------------
<#
This call should be made at the beginning of every script to be sure the version is filled (and the connection could be made)
#>

if ( $settings.checkVersion ) { 

    #$res = Invoke-RestMethod -Uri $url -Method get -Verbose -Headers $headers -ContentType $contentType
    $elaineVersion = Invoke-ELAINE -function "api_getElaineVersion"
    # or like this to get it back as number
    #$elaineVersion = Invoke-ELAINE -function "api_getElaineVersion" -method "Post" -parameters @($true)

    Write-Log -message "Using ELAINE version '$( $elaineVersion )'"

}

# Use this function to check if a mininum version is needed to call the function
#Check-ELAINE-Version -minVersion "6.2.2"


#-----------------------------------------------
# GROUP HANDLING
#-----------------------------------------------

# TODO [ ] Check the need of groups for transactional mailings
<#
# If lists contains a concat character (id+name), use the list id
# if no concat character is present, take the whole string as name for a new list and search for it... if not present -> new list!
# if no list is present, just take the current date and time
$listItems = $params.ListName -split $settings.nameConcatChar
$createNewGroup = $true
if ( $listItems[1].count -gt 0 ) {

    $listName = $listItems[0]
    $groupId = $listName
    $createNewGroup = $false

} elseif ( $listItems[0].count -gt 0 ) {
    
    $listNameTxt = $listItems[0]

    # Try to search for that group
    $object = "groups"    
    $endpoint = "$( $apiRoot )$( $object )"
    $groups = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -Verbose -ContentType "application/json; charset=utf-8"
    
    $matchGroups = ( $groups | where { $_.name -eq $listNameTxt } | sort stamp -Descending | Select -first 1 ).id

    if ( $matchGroups.count -ne "" ) {
        $listName = $matchGroups
        $groupId = $listName
        $createNewGroup = $false
    } else {
        $listName = $listNameTxt
    }


} else {

    $listName = [datetime]::Now.ToString("yyyyMMdd HHmmss")

}


#>


#-----------------------------------------------
# PARSE GROUP AND LOAD DETAILS
#-----------------------------------------------
<#
# TODO [ ] Activate group dependent features
$group = [Group]::New($params.ListName)

# Load details from ELAINE to check if it still exists
$groupDetails = Invoke-ELAINE -function "api_getDetails" -parameters @("Group",[int]$group.groupId)
#>

#-----------------------------------------------
# PARSE MAILING AND LOAD DETAILS
#-----------------------------------------------

<#

mailingId mailingName
--------- -----------
1875      Apteco PeopleStage Training Automation

#>
$mailing = [Mailing]::New($params.MessageName)

# Load details from ELAINE to check if it still exists
$mailingDetails = Invoke-ELAINE -function "api_getDetails" -parameters @("Mailing",[int]$mailing.mailingId)
if ( $mailingDetails.status_data.is_transactionmail ) {
    Write-Log -message "Mailing is confirmed as a transactional mailing"
} else {
    Write-Log -message "Mailing is no transactional mailing"
    throw [System.IO.InvalidDataException] "Mailing is no transactional mailing"
}


#-----------------------------------------------
# IMPORT DATA
#-----------------------------------------------

$dataCsv = Import-Csv -Path $params.Path -Delimiter "`t" -Encoding UTF8 -Verbose
Write-Log -message "Loaded '$( $dataCsv.count )' records"


#-----------------------------------------------
# LOAD FIELDS
#-----------------------------------------------

# TODO [ ] Loading only C fields or think of group dependent fields, too?
$fields = Invoke-ELAINE -function "api_getDatafields"
#$fields | Out-GridView

<#
# Load group fields
# TODO [ ] Activate group dependent features
$fields += Invoke-ELAINE -function "api_getDatafields" -parameters @([int]$group.groupId)
#>

Write-Log -message "Loaded fields $( $fields.f_name -join ", " )"


#-----------------------------------------------
# FIELD MAPPING
#-----------------------------------------------

# Check csv fields
$csvAttributesNames = Get-Member -InputObject $dataCsv[0] -MemberType NoteProperty 
Write-Log -message "Loaded csv attributes $( $csvAttributesNames.Name -join ", " )"

# Create mapping for source and target
$colMap = [System.Collections.ArrayList]@()

# Add URN column
$colMap.Add(
    [PSCustomObject]@{
        "source" = $params.UrnFieldName
        "target" = $settings.upload.urnColumn
    }
)

# Add email column
$colMap.Add(
    [PSCustomObject]@{
        "source" = $params.EmailFieldName
        "target" = $settings.upload.emailColumn
    }
)

# Save which fields are required
$requiredFields = $colMap.source
if ( $settings.upload.requiredFields -ne $null ) {
    $requiredFields += $settings.upload.requiredFields
}
Write-Log -message "Required fields '$( $requiredFields -join ", " )'"

# Which columns are remaining in csv?
$remainingColumns = $csvAttributesNames | where { $_.name -notin $colMap.source  }

# Check corresponding field names
$compareNames = Compare-Object -ReferenceObject $fields.f_name -DifferenceObject $remainingColumns.Name -IncludeEqual -PassThru | where { $_.SideIndicator -eq "==" }
$compareNames | ForEach {
    $fieldname = $_
    $colMap.Add(
        [PSCustomObject]@{
            "source" = $fieldname
            "target" = $fieldname
        }
    )
}

# Which columns are still remaining in csv?
$remainingColumns = $csvAttributesNames | where { $_.name -notin $colMap.source  }

# Check corresponding field labels
$compareLabels = Compare-Object -ReferenceObject $fields.f_label -DifferenceObject $remainingColumns.Name  -IncludeEqual -PassThru  | where { $_.SideIndicator -eq "==" }
$compareLabels | ForEach {
    $fieldlabel = $_
    $colMap.Add(
        [PSCustomObject]@{
            "source" = $fieldlabel
            "target" = $fields.where({ $_.f_label -eq $fieldlabel }).f_name
        }
    )
}

# Which columns are still remaining in csv?
$remainingColumns = $csvAttributesNames | where { $_.name -notin $colMap.source  }

# Add remaining columns as t_ columns
$remainingColumns | ForEach {
    $columnName = $_
    $colMap.Add(
        [PSCustomObject]@{
            "source" = $columnName.Name
            "target" = "t_$( $columnName.Name.ToLower().replace(" ","_") )" # TODO [ ] check if maybe more is needed
        }
    )
    
}


# TODO [ ] Test required fields object in settings
# TODO [ ] Test with and without variant field defined in settings

# Add variant name if present
if ( $settings.upload.variantColumn -ne $null ) {
    $requiredFields += $settings.upload.variantColumn
}

# Check if required fields are present
$equalWithRequirements = Compare-Object -ReferenceObject $csvAttributesNames.Name -DifferenceObject $requiredFields -IncludeEqual -PassThru | where { $_.SideIndicator -eq "==" }
if ( $equalWithRequirements.count -eq $requiredFields.Count ) {
    # Required fields are all included
    Write-Log -message "All required fields are present"
} else {
    # Required fields not equal -> error!
    throw [System.IO.InvalidDataException] "Not all required fields are present!"  
}


#-----------------------------------------------
# CREATE UPLOAD OBJECT
#-----------------------------------------------

$urnFieldName = $params.UrnFieldName
$commkeyFieldName = $params.CommunicationKeyFieldName
$variantColumnName = $settings.upload.variantColumn

$recipients = [System.Collections.ArrayList]@()
$dataCsv | ForEach {

    $row = $_

    # Use variant column
    if ( $variantColumnName -ne "" ) {
        $variant = $row.$variantColumnName
    } else {
        $variant = ""
    }

    $entry = [PSCustomObject]@{
        "variant" = $variant
        "data" = [PSCustomObject]@{}
    }

    $colMap | where { $_.target -ne $variantColumnName } | ForEach {
        $source = $_.source
        $target = $_.target
        $entry.data | Add-Member -MemberType NoteProperty -Name $target -Value $row.$source
    }

    $recipients.Add($entry)

}
exit 0

#-----------------------------------------------
# SEND SINGLE TRANSACTIONAL
#-----------------------------------------------
<#
Upload an array in the api call and send email directly
Recipients on black and bounce lists are NOT automatically excluded, but this can be controlled via the blacklist parameter
BULK: Additionally to the non-bulk mode, the bulk mechanism uses the bounce list; Only possible for one mailing id and abortOnError will be ignored -> Either the whole call will be send out or not
#>

$variant = "" # TODO [ ] check if you can read the variants of a mailing

# TODO [ ] Check the usage of the notification url with webhooks
# Create the upload data object
$dataArr = [ordered]@{
    "content" = [ordered]@{
        "c_urn"             = "414596"
        "c_email"          = "test@example.tld"
        #"t_subject"        = "Test-Betreff"
        #"t_sendername"     = "Apteco GmbH"
        #"t_sender"         = "info@apteco.de"
        #"t_replyto" $       = "antwort@example.tld"
        #"t_cc"             = "cc_empfaenger@example.tld"
        #"t_bcc"            = "bcc_empfaenger@example.tld"
        #"t_attachment"     = @()
        #"t_textcontent"    = "Text-Inhalt"
        #"t_htmlcontent"    = "HTML-Inhalt"
        #"t_xxx"            = "Hello World"
    }
    "priority" = $settings.upload.priority        
    "override" = $settings.upload.override
    "update_profile" = $settings.upload.updateProfile
    "msgid" = $processId    # External message id / for identifying
    #"notify_url" = ""              # notification url if bounced, e.g. like "http://notifiysystem.de?email=[c_email]"
}

$jsonInput = @(
    $dataArr                        # array $data = null                    Recipient data
    [int]$mailing.mailingId         # int $nl_id                            Mailing
    "" #$selectedGroup[0].ev_id    # int $ev_id                            Group is optional
    $variant                        # int $variant_position : null
    #$false                         # boolean|integer $blacklist : true     false means the blacklist will be ignored, a group id can also be passed and then used as an exclusion list
) 
$send = Invoke-ELAINE -function "api_sendSingleTransaction" -method Post -parameters $jsonInput

# TODO [x] Needs testing
# TODO [ ] Add BULK and Single send to the the settings creation or make id dependent on the version


#-----------------------------------------------
# GET TRANSACTIONAL MAILING STATUS
#-----------------------------------------------

# TODO [ ] Define max timeout for checking status or use sync and async mode like in Epi

$function = "api_getTransactionMailStatus"
$jsonInput = @(
    [int]$send      # int $id
    $false          # bool $is_msgid -> true if the id is an external message id

) 
$restParams = $defaultRestParamsPost + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Body = "json=$( Format-ELAINE-Parameter $jsonInput )"
}
$transactionalStatus = Invoke-RestMethod @restParams
$transactionalStatus












#-----------------------------------------------
# CREATE UPLOAD OBJECT
#-----------------------------------------------


$urnFieldName = $params.UrnFieldName
$commkeyFieldName = $params.CommunicationKeyFieldName
$recipients = @()
$dataCsv | ForEach {

    $addr = $_

    $address = [PSCustomObject]@{}
    $requiredFields | ForEach {
        $address | Add-Member -MemberType NoteProperty -Name $_ -Value $addr.$_
    }
    $colsEqual.InputObject | ForEach {
        $address | Add-Member -MemberType NoteProperty -Name $_ -Value $addr.$_
    }

    $recipient = [PSCustomObject]@{
        "urn" = $addr.$urnFieldName
        "communicationkey" = $addr.$commkeyFieldName #[guid]::NewGuid()
        "address" = $address <#[PSCustomObject]@{
            #"title" = ""
            #"otherTitles" = ""
            #"jobTitle" = ""
            #"gender" = ""
            #"companyName1" = ""
            #"companyName2" = ""
            #"companyName3" = ""
            #"individualisation1" = ""
            #"individualisation2" = ""
            #"individualisation3" = "" # could be used also with 4,5,6....
            #"careOf" = ""
            "firstName" = $firstnames | Get-Random
            "lastName" = $lastnames | Get-Random
            #"fullName" = ""
            "houseNumber" = $addr.hnr
            "street" = $addr.strasse
            #"address1" = ""
            #"address2" = ""
            "zipCode" = $addr.plz
            "city" = $addr.stadtbezirk
            #"country" = ""
        }#>
        "variation" = $addr.variation #$variations | Get-Random 
        "vouchers" = @() # array of @{"code"="XCODE123";"name"="voucher1"}
    }
    $recipients += $recipient
}


# $recipients | ConvertTo-Json -Depth 20 | set-content -Path ".\recipients.json" -Encoding UTF8 

Write-Log -message "Loaded $( $dataCsv.Count ) records"

$url = "$( $settings.base )/v2/automations/$( $automationID )/recipients"
$results = @()
if ( $recipients.Count -gt 0 ) {
    
    $chunks = [Math]::Ceiling( $recipients.count / $batchsize )

    $t = Measure-Command {
        for ( $i = 0 ; $i -lt $chunks ; $i++  ) {
            
            $start = $i*$batchsize
            $end = ($i + 1)*$batchsize - 1

            # Create body for API call
            $body = @{
                "addresses" = $recipients[$start..$end] | Select * -ExcludeProperty Urn,communicationkey
            }

            # Check size of recipients object
            Write-Host "start $($start) - end $($end) - $( $body.addresses.Count ) objects"

            # Do API call
            $bodyJson = $body | ConvertTo-Json -Verbose -Depth 20
            $result = Invoke-RestMethod -Verbose -Uri $url -Method Post -Headers $headers -ContentType $contentType -Body $bodyJson -TimeoutSec $maxTimeout
            $results += $result
            
            # Append result to the record
            for ($j = 0 ; $j -lt $result.results.Count ; $j++) {
                $singleResult = $result.results[$j] 
                if ( ( $singleResult | Get-Member -MemberType NoteProperty | where { $_.Name -eq "id" } ).Count -gt 0) {
                    # If the result contains an id
                    $recipients[$start + $j] | Add-Member -MemberType NoteProperty -Name "success" -Value 1
                    $recipients[$start + $j] | Add-Member -MemberType NoteProperty -Name "result" -Value $singleResult.id
                } else {
                    # If the results contains an error
                    $recipients[$start + $j] | Add-Member -MemberType NoteProperty -Name "success" -Value 0
                    $recipients[$start + $j] | Add-Member -MemberType NoteProperty -Name "result" -Value $singleResult.error.message

                }
                #$recipients[$start + $j].Add("result",$value)
                
            }

            # Log results of this chunk
            Write-Host "Result of request $( $result.requestId ): $( $result.queued ) queued, $( $result.ignored ) ignored"
            Write-Log -message "Result of request $( $result.requestId ): $( $result.queued ) queued, $( $result.ignored ) ignored"

        }
    }
}

# Calculate results in total
$queued = ( $results | Measure-Object queued -sum ).Sum
$ignored = ( $results | Measure-Object ignored -sum ).Sum
if ( $ignored -gt 0 ) {
    $errMessages = $results.results.error.message | group -NoElement
}

# Log the results
Write-Log -message "Queued $( $queued ) of $( $dataCsv.Count  ) records in $( $chunks ) chunks and $( $t.TotalSeconds   ) seconds"
Write-Log -message "Ignored $( $ignored ) records in total"
$errMessages | ForEach {
    $err = $_
    Write-Log -message "Error '$( $err.Name )' happened $( $err.Count ) times"
}

# Export the results
$resultsFile = "$( $uploadsFolder )$( $processId ).csv"
$recipients | select * -ExpandProperty address  -ExcludeProperty address | Export-Csv -Path $resultsFile -Encoding UTF8 -NoTypeInformation -Delimiter "`t"
Write-Log -message "Written results into file '$( $resultsFile )'"




################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

If ( $queued -eq 0 ) {
    Write-Host "Throwing Exception because of 0 records"
    throw [System.IO.InvalidDataException] "No records were successfully uploaded"  
}

# return object
$return = [Hashtable]@{

    # Mandatory return values
    "Recipients"=$queued 
    "TransactionId"=$processId

    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider"=$moduleName
    "ProcessId" = $processId

    # Some more information for the broadcasts script
    "EmailFieldName"= $params.EmailFieldName
    "Path"= $params.Path
    "UrnFieldName"= $params.UrnFieldName

    # More information about the different status of the import
    "RecipientsIgnored" = $ignored
    "RecipientsQueued" = $queued

}

# return the results
$return