
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
	    EmailFieldName= "Email"
	    TransactionType= "Replace"
	    Password= "def"
	    scriptPath= "C:\FastStats\scripts\syniverse_validation"
	    MessageName= "Validate globally"
	    SmsFieldName= ""
	    Path= "C:\FastStats\Publish\Handel\system\deliveries\PowerShell Validate globally_66ce38fd-191a-48b9-885f-eca1bac20803.txt"
	    ReplyToEmail= ""
	    Username= "abc"
	    ReplyToSMS= ""
	    UrnFieldName= "Urn"
	    ListName= "Validate globally"
	    CommunicationKeyFieldName= "Communication Key"
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
$settingsFilename = "settings.json"
$moduleName = "UPLOAD"
$processId = [guid]::NewGuid()

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
$maxWriteCount = $settings.rowsPerUpload
$uploadsFolder = $settings.uploadsFolder

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


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
        Write-Log -message " $( $param ): $( $params[$param] )"
    }
}


################################################
#
# CREATE FILES TO CHECK
#
################################################

#-----------------------------------------------
# ATTRIBUTES
#-----------------------------------------------

$cols = ,@($params.SmsFieldName)


#-----------------------------------------------
# DATA MAPPING
#-----------------------------------------------

Write-Log -message "Start to create a new file"

$t = Measure-Command {
    $fileItem = Get-Item -Path $params.Path
    #$exportId = Split-File -inputPath $params.Path -header $true -writeHeader $false -inputDelimiter "`t" -outputDelimiter "`t" -outputColumns $cols -writeCount -1 -outputDoubleQuotes $true
    $exportId = Split-File -inputPath $fileItem.FullName `
                           -header $true `
                           -writeHeader $false `
                           -inputDelimiter "`t" `
                           -outputDelimiter "`t" `
                           -outputColumns $cols `
                           -writeCount -1 `
                           -outputDoubleQuotes $true `
                           -outputPath $uploadsFolder
}

Write-Log -message "Done with export id $( $exportId ) in $( $t.Seconds ) seconds!"


################################################
#
# PREPARE REQUEST FOR SYNIVERSE VALIDATION
#
################################################

#-----------------------------------------------
# PREPARE GENERIC HEADERS
#-----------------------------------------------

$headers = @{
    "Authorization"= "Bearer $( Get-SecureToPlaintext -String $settings.authentication.accessToken )"
    "Content-Type"= "application/json"
}


#-----------------------------------------------
# LOAD DATA LAYOUTS
#-----------------------------------------------

# get layouts
$url = "$( $settings.base )aba/v1/layouts"
$layouts = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -Verbose 

# $layouts | Out-GridView

# TODO [ ] check if outputs with higher version numbers could be useful
# TODO [ ] put the selection of layouts into settings creation powershell

# choose layouts
$inputLayout = $layouts | where { $_.name -eq $settings.nisscrub.inputLayoutName }
$outputLayout = $layouts | where { $_.name -eq $settings.nisscrub.outputLayoutName }


################################################
#
# READ FOLDER FOR NUMBER VALIDATION
#
################################################

Get-ChildItem -Path "$( $uploadsFolder )\$( $exportId )" | ForEach-Object {
    

    #-----------------------------------------------
    # FILE PREPARATIONS
    #-----------------------------------------------

    # inputfile
    $tmp = $_
    $tempfile = $tmp.FullName

    # create new guid
    # TODO [ ] replace this guid with process id?
    $validateId = [guid]::NewGuid()

    # Filenames
    $tempFolder = "$( $exportFolder )\$( $validateId )"
    New-Item -ItemType Directory -Path $tempFolder
    $successFile = "$( $tempFolder )\success.gz"
    $errorFile = "$( $tempFolder )\error.txt"
    $retryFile = "$( $tempFolder )\retry.txt"


    #-----------------------------------------------
    # CREATE NEW FILE IN MEDIACENTER
    #-----------------------------------------------

    # create empty file at syniverse mediacenter
    $body = $settings.mediacenter.emptyFileContent | ConvertTo-json -Depth 8 -Compress
    $url = "$( $settings.base )mediastorage/v1/files"

    # create new file content    
    $newFile = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -Verbose 

    
    #-----------------------------------------------
    # LOAD FILE METADATA
    #-----------------------------------------------

    # fill variables with information from mediacenter call
    if ( $newFile.file_status -eq "CREATED" ) {

        # get the file_id, company id from the create file response
        $fileId = $newFile."file_id"
        $companyId = $newFile."company-id"

        # the URL to use in the request also comes from the create file response
        $uploadUri = $newFile."file_uri"

        #log 
        Write-Log -message "Created new file online with id $( $fileId )"

    }


    #-----------------------------------------------
    # PREPARE UPLOAD AND DOWNLOAD HEADERS
    #-----------------------------------------------

    # upload headers
    $uploadHeaders = @{
        "Authorization"=$headers.Authorization
        "int-companyid"=$companyId
        "Content-Type"="application/octet-stream"
    }

    # download headers
    $downloadHeaders = @{
        "Authorization"=$headers.Authorization
        "int-companyid"=$companyId
    }

    #-----------------------------------------------
    # UPLOAD FILE
    #-----------------------------------------------

    #$upload = Invoke-RestMethod -Uri $uploadUri -Method Post -Headers $uploadHeaders -Verbose -InFile $tempfile
    $upload = Invoke-WebRequest -Headers $uploadHeaders -Uri  $uploadUri -Verbose -Method POST -InFile $tempfile  # From Powershell 6 on we can directly use Invoke-Restmethod to get the headers
    Write-Log -message "Status $( $upload.StatusCode ) with url $( $upload.Headers.Location )"


    #-----------------------------------------------
    # CREATE AND SCHEDULE JOB FOR BATCH AUTOMATION
    #-----------------------------------------------
    
    # Scheduling the Number Verification batch job in Batch Automation'

    $url = "$( $settings.base )aba/v1/schedules"

    $scheduleJobPayload = @{
        "schedule"=@{
            "jobId"="NIS-Scrub-v2-fs1"
            "name"="NISScrub"
            "inputFileId"=$fileId
            "fileRetentionDays"=$newFile.file_retention_time
            "scheduleRetentionDays"=$newFile.file_retention_time
            "outputFileNamingExpression"="DS1-NIS-Scrub-output.txt"
            "outputFileFolder"="/opt/apps/aba/output"
        }
    }

    $scheduleJobPayloadJson = $scheduleJobPayload | ConvertTo-Json -Depth 8 -Compress

    $tries = 0
    $callSuccessfull = $false
    Do {
        try {
            $scheduleJob = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $scheduleJobPayloadJson -Verbose 
            $callSuccessfull = $true
        } catch {
            Write-Host $_.Exception
            $tries += 1
            Start-Sleep -Milliseconds $settings.mediacenter.waitBetweenTries
        } 
    } Until ( $callSuccessfull -or $tries -ge 3 )

    $jobId = $scheduleJob.schedule.id

    Write-Log -message "Scheduled job with id $( $jobId )"

    
    #-----------------------------------------------
    # CHECK FOR JOB COMPLETION
    #-----------------------------------------------
    
    <#

    INFO example of different status messages

    "status":  "PENDING","statusReason":  null,
    "status":  "ACCEPTED","statusReason":  "Starting Job",
    "status":  "NOTIFY_STARTED","statusReason":  "notify sent",
    "status":  "NOTIFY_STARTED","statusReason":  "1580936 JobID. OnStart steps.",
    "status":  "BATCH_STARTED","statusReason":  "1580936 JobID",
    "status":  "BATCH_COMPLETE","statusReason":  "1580936 JobID. OnCompletion steps.",
    "status":  "OUTPUT_POSTED","statusReason":  "output uploaded",
    "status":  "COMPLETE","statusReason":  "Final Status",

    #>

    # check until last execution status is "COMPLETE"
    # TODO [ ] how to check that there was an error?
    $tries = 0
    Do {
        $url = "$( $settings.base )aba/v1/schedules/$( $jobId )/executions"
        $jobStatus = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -Verbose 
        $jobStatus | ConvertTo-Json
        Start-Sleep -Milliseconds $settings.mediacenter.waitBetweenTries 
    } Until ( $jobStatus.executions.where({ $_.scheduleDetail.id -eq $jobId }).status -eq "COMPLETE" -or $tries++ -eq $settings.mediacenter.maxTries-1)
    

    #-----------------------------------------------
    # DOWNLOAD RESULTS
    #-----------------------------------------------
    
    $completedJob = $jobStatus.executions.where({ $_.scheduleDetail.id -eq $jobId })

    # check if there is a result
    if ( $completedJob ) {
        
        Write-Log -message "Job complete, downloading files"

        #stats
        ( $completedJob.statusUpdateTimestamp - $completedJob.startTimestamp ) / 1000 # duration in seconds    
        $completedJob.recordSuccessCount # number of successful numbers
        $completedJob.recordRetryCount # number of retries
        $completedJob.recordErrorCount # number or errors
    
        # header for output files
        $outputHeader = $outputLayout.recordLayout.name -join $outputLayout.fieldDelimiter

        # download and unzip the result files
        if ( $completedJob.outputFileURI -ne "EMPTY_FILE" ) {
            Invoke-RestMethod -Uri $completedJob.outputFileURI -Method Get -Headers $downloadHeaders -Verbose -OutFile $successFile
            $successItem = get-item -path $successFile
            $successDecompressedFile = ( $successItem.FullName -replace $successItem.Extension,".csv" )
            DeGZip-File -infile $successFile -outfile $successDecompressedFile -deleteFileAfterUnzip $true
            rewriteFileAsStream -inputPath $successDecompressedFile -inputEncoding ([System.Text.Encoding]::UTF8.CodePage) -outputPath $successDecompressedFile -outputEncoding ([System.Text.Encoding]::UTF8.CodePage) -skipFirstLines 0 -headerLine $outputHeader
        } 
    
        if ( $completedJob.errorDetailFileURI -ne "EMPTY_FILE" ) {
            Invoke-RestMethod -Uri $completedJob.errorDetailFileURI -Method Get -Headers $downloadHeaders -Verbose -OutFile $errorFile
            #$errorItem = get-item -path $errorFile
            #$errorDecompressedFile = ( $errorItem.FullName -replace $errorItem.Extension,".csv" )
            #DeGZip-File -infile $errorFile -outfile $errorDecompressedFile
        }

        if ( $completedJob.retryFileURI -ne "EMPTY_FILE" ) {
            Invoke-RestMethod -Uri $completedJob.retryFileURI -Method Get -Headers $downloadHeaders -Verbose -OutFile $retryFile
            #$retryItem = get-item -path $retryFile
            #$retryDecompressedFile = ( $retryItem.FullName -replace $retryItem.Extension,".csv" )
            #DeGZip-File -infile $retryFile -outfile $retryDecompressedFile
        }

    } 
    
    #-----------------------------------------------
    # DELETE FILES ONLINE
    #-----------------------------------------------
    <#
    # TODO [ ] DELETE does not work properly

    # deletion works, even if status = 500 -> 
    if ( $completedJob ) {
    
        # delete input file
        $url = "$( $settings.base )mediastorage/v1/files/$( $fileId )"
        try {
            Invoke-WebRequest -Uri $url -Method Delete -Headers $headers -Verbose -TimeoutSec $settings.mediacenter.timeoutSecForDeletion
        } catch {

        }

        # delete output files
        if ( $completedJob.outputFileURI -ne "EMPTY_FILE" ) {
            try {
                Invoke-RestMethod -Uri "$( $settings.base )mediastorage/v1/files/$( $completedJob.outputFileId )" -Method Delete -Headers $headers -Verbose  -TimeoutSec $settings.mediacenter.timeoutSecForDeletion
            } catch {

            }
        } 
    
        if ( $completedJob.errorDetailFileURI -ne "EMPTY_FILE" ) {
            try {
                Invoke-RestMethod -Uri "$( $settings.base )mediastorage/v1/files/$( $completedJob.errorDetailFileId )" -Method Delete -Headers $headers -Verbose  -TimeoutSec $settings.mediacenter.timeoutSecForDeletion
            } catch {

            }
        }

        if ( $completedJob.retryFileURI -ne "EMPTY_FILE" ) {
            try {
                Invoke-RestMethod -Uri "$( $settings.base )mediastorage/v1/files/$( $completedJob.retryFileId )" -Method Delete -Headers $headers -Verbose -TimeoutSec $settings.mediacenter.timeoutSecForDeletion
            } catch {

            }
        }

    } 

    #>




}


################################################
#
# APPEND TO IMPORT FILE
#
################################################

#$successDecompressedFile
# TODO [ ] in the end this command should combine the files and not overwrite it

Copy-Item -Path $successDecompressedFile -Destination "D:\FastStats\Publish\FUG\public\Variables" -Force


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# count the number of successful upload rows
$recipients = 0 # ( $importResults | where { $_.Result -eq 0 } ).count

# There is no id reference for the upload in Epi
$transactionId = 0 #$recipientListID

# return object
[Hashtable]$return = @{
    
    # Mandatory return values
    "Recipients" = $recipients
    "TransactionId" = $transactionId
    
    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider" = $settings.providername

}

# return the results
$return

