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
$removeRecipientsAfterUpload = $true


#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
        TransactionType= "Replace"
        Password= "def"
        scriptPath= "D:\Scripts\Optilyz"
        MessageName= "5fc6ca6a89b5e200e0de42e0 / Test Automation Apteco"
        EmailFieldName= "Email"
        SmsFieldName= ""
        Path= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\Optilyz\REST\random100.csv"
        ReplyToEmail= ""
        Username= "abc"
        ReplyToSMS= ""
        UrnFieldName= "Urn"
        ListName= "Free Try Automation"
        CommunicationKeyFieldName= "Communication Key"
    }
}

################################################
#
# NOTES
#
################################################

<#

TODO [ ] implement vouchers

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
$moduleName = "OPTLZUPLOAD"
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
# CHECK RESULTS FOLDER
#-----------------------------------------------

$uploadsFolder = $settings.upload.uploadsFolder
if ( !(Test-Path -Path $uploadsFolder) ) {
    Write-Log -message "Upload $( $uploadsFolder ) does not exist. Creating the folder now!"
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}


#-----------------------------------------------
# CONFIG
#-----------------------------------------------

#$automationID = "5fc6ca6a89b5e200e0de42e0 / Test Automation Apteco"
$automation = [OptilyzAutomation]::New($params.MessageName)
$automationID = $automation.automationId

# TODO [ ] uncomment these settings
$batchsize = $settings.upload.rowsPerUpload # Is 1000 in optilyz documentation
$maxTimeout = $settings.upload.timeout # normally the results should be sent back in less than 15 seconds


#-----------------------------------------------
# AUTH & HEADERS
#-----------------------------------------------

# Step 2. Encode the pair to Base64 string
$encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$( Get-SecureToPlaintext $settings.login.token ):"))
 
# Step 3. Form the header and add the Authorization attribute to it
$headers = @{ Authorization = "Basic $encodedCredentials" }
$contentType = "application/json;charset=utf-8"


#-----------------------------------------------
# IMPORT DATA
#-----------------------------------------------

#$dataCsv = Import-Csv -Path ".\random100.csv" -Delimiter "`t" -Encoding UTF8 -Verbose
#$dataCsv = Import-Csv -Path ".\random3500.csv" -Delimiter "`t" -Encoding UTF8 -Verbose
$dataCsv = Import-Csv -Path $params.Path -Delimiter "`t" -Encoding UTF8 -Verbose

# https://de.wikipedia.org/wiki/Liste_deutscher_Vornamen_aus_der_Bibel
#$firstnames = @("Aaron","Abraham","Ada","Adam","Andreas","Anna","Balthasar","Benjamin","Christian","Daniel","David","Debora","Delila","Elias","Elisabeth")
# https://www.bedeutung-von-namen.de/top50-nachnamen-deutschland
#$lastnames = @("Müller","Schmidt","Schneider","Fischer","Meyer","Weber","Hofmann",	"Wagner","Becker",	"Schulz",	"Schäfer",	"Koch",	"Bauer","Richter","Klein")


#-----------------------------------------------
# CHECK AUTOMATION
#-----------------------------------------------

# Get automation data like variations
Try {
    $automationDetails = Invoke-RestMethod -Verbose -Uri "$( $settings.base )/v2/automations/$( $automationID )" -Method Get -Headers $headers -ContentType $contentType #-Body $bodyJson -TimeoutSec $maxTimeout
} Catch {
    throw [System.IO.InvalidDataException] "Automation id does not exist, maybe not live anymore"  
}

# Get visuals
#Invoke-RestMethod -Verbose -Uri "$( $settings.base )/v2/automations/$( $automationID )/visuals" -Method Get -Headers $headers -ContentType $contentType #-Body $bodyJson -TimeoutSec $maxTimeout

# Get campaigns
#Invoke-RestMethod -Verbose -Uri "$( $settings.base )/v2/automations/$( $automationID )/campaigns" -Method Get -Headers $headers -ContentType $contentType #-Body $bodyJson -TimeoutSec $maxTimeout

# TODO [ ] change this
#$variations = @("1","2","A") #$automationDetails.variations.id


#-----------------------------------------------
# LOAD FIELDS
#-----------------------------------------------

$fields = Invoke-RestMethod -Verbose -Uri "$( $settings.base )/v1/dataMappingFields" -Method Get -Headers $headers -ContentType $contentType #-Body $bodyJson -TimeoutSec $maxTimeout

<#
label                 fieldName          required type      
-----                 ---------          -------- ----
Title                 jobTitle              False string
Salutation            title                 False string
First Name            firstName             False string
Last Name             lastName               True string
Company Name          companyName1          False string
Company Name 2        companyName2          False string
Company Name 3        companyName3          False string
Street                street                 True string    
House Number          houseNumber           False string
Other address details address2              False string
More address details  address3              False string
Zip Code              zipCode                True string
City                  city                   True string
Country               country               False string
Individualisation     individualisations    False collection
c/o (care of)         careOf                False string
Gender                gender                False string
Other titles          otherTitles           False string
#>

Write-Log -message "Loaded attributes $( $fields.fieldName -join ", " )"

#-----------------------------------------------
# FIELD MAPPING
#-----------------------------------------------

# Check required fields
$requiredFields = ($fields | where { $_.required -eq $true }).fieldName
Write-Log -message "Required fields $( $requiredFields -join ", " )"

# Check optional fields
$attributesNames = $fields | where { $_.fieldName -notin $requiredFields }

# Check csv fields
$csvAttributesNames = Get-Member -InputObject $dataCsv[0] -MemberType NoteProperty 
Write-Log -message "Loaded csv attributes $( $csvAttributesNames.Name -join ", " )"

# Check if email field is present
$equalWithRequirements = Compare-Object -ReferenceObject $csvAttributesNames.Name -DifferenceObject $requiredFields -IncludeEqual -PassThru | where { $_.SideIndicator -eq "==" }
if ( $equalWithRequirements.count -eq $requiredFields.Count ) {
    # Required fields are all included
    Write-Log -message "All required fields are present"
} else {
    # Required fields not equal -> error!
    throw [System.IO.InvalidDataException] "Not all required fields are present!"  
}

# Compare columns
# TODO [ ] Now the csv column headers are checked against the name of the optilyz attributes
$differences = Compare-Object -ReferenceObject $attributesNames.fieldName -DifferenceObject ( $csvAttributesNames  | where { $_.name -notin $requiredFields } ).name -IncludeEqual #-Property Name 
$colsEqual = $differences | where { $_.SideIndicator -eq "==" } 
$colsInAttrButNotCsv = $differences | where { $_.SideIndicator -eq "<=" } 
$colsInCsvButNotAttr = $differences | where { $_.SideIndicator -eq "=>" }
Write-Log -message "Only fields $( $colsEqual.InputObject -join "," ) are matching"


#-----------------------------------------------
# CREATE UPLOAD OBJECT
#-----------------------------------------------

# TODO [ ] decisions to make: fullName or firstName+lastName / address1 or street+houseNumber / companyName if no fullname or lastname -> automatically checked from optilyz at upload

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

# Remove all recipients - DEBUG
if ( $removeRecipientsAfterUpload ) {
    $results.results.id | where { $_ -ne $null } | ForEach {
        Invoke-RestMethod -Verbose -Uri "$( $settings.base )/v2/automations/$( $automationID )/recipients/$( $id )" -Method Delete -Headers $headers -ContentType $contentType
    }
}


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

}

# return the results
$return