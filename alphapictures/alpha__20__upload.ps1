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

# TODO [ ] add more log messages

#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{

        # Integration parameters
        #"scriptPath" = "D:\Scripts\alphapictures"
        #"importFile" = "D:\FastStats\Publish\Handel\public\alphapictures.csv"
        
        # PeopleStage
        "TransactionType" = "Replace"
        "Password" = "cd"
        "scriptPath" = "D:\Scripts\alphapictures"
        "MessageName" = "1087 | 1 | Greeting Card with Balloons - 1 - "
        "EmailFieldName" = "email"
        "SmsFieldName" = ""
        "Path" = "D:\Apteco\Publish\GV\system\Deliveries\PowerShell_1087  1  Greeting Card with Balloons - 1 - _53808900-1d48-48b5-862d-40c306e7af95.txt"
        "ReplyToEmail" = ""
        "Username" = "ab"
        "ReplyToSMS" = ""
        "UrnFieldName" = "Con Acc Id"
        "importFile" = "D:\Apteco\Publish\GV\public\alphapictures.csv"
        "CommunicationKeyFieldName" = "Communication Key"
        "ListName" = "1087 | 1 | Greeting Card with Balloons - 1 - "

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
$moduleName = "APUPLOAD"
$processId = [guid]::NewGuid()

# Load settings
# TODO [ ] put settings into file
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
$settings = @{
    
    base = "https://v4.alphapicture.com/"
    
    changeTLS = $true
    nameConcatChar = " | "
    logfile = ".\alpha.log"

    login = @{
        account = "<accountname>"
        password = "<password>"
    }

    upload = @{
        defaultUseWatermark = $false
        uploadsFolder = "$( $scriptPath )\results"
        waitForSuccess = $true
        timeout = 600
    }

    download = @{
        waitSecondsLoop = 10
    }

    preview = @{
        "Type" = "Email" #Email|Sms
        #"FromAddress"="info@apteco.de"
        #"FromName"="Apteco"
        "ReplyTo"="info@apteco.de"
        #"Subject"="Test-Subject"
    }

}
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

#Add-Type -AssemblyName System.Data

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

$uploadsFolder = $settings.upload.uploadsFolder
if ( !(Test-Path -Path $uploadsFolder) ) {
    Write-Log -message "Upload $( $uploadsFolder ) does not exist. Creating the folder now!"
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}


#-----------------------------------------------
# PREPARE ALPHAPICTURES OBJECT
#-----------------------------------------------

#$stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $settings.login.password ) -AsPlainText -Force
# TODO [ ] create secured password
$stringSecure = ConvertTo-SecureString -String $settings.login.password -AsPlainText -Force
$cred = [pscredential]::new( $settings.login.account, $stringSecure )

# Create alphapictures object
$alpha = [AlphaPictures]::new($cred,$settings.base)


#-----------------------------------------------
# GET MOTIFS
#-----------------------------------------------

$motifs = $alpha.getMotifs()
Write-log -message "Loaded '$( $motifs.count )' motifs with '$( $motifs.alternatives.count )' alternatives in total"


#-----------------------------------------------
# CHOOSE THE SELECTED MOTIF ALTERNATIVE
#-----------------------------------------------

$chosenMotifAlternative = [MotifAlternative]::new($params.MessageName)
$motifAlternative = $motifs.alternatives | where { $_.motif.id -eq $chosenMotifAlternative.motif.id -and $_.id -eq $chosenMotifAlternative.id }
Write-log -message "Using the motif '$( $chosenMotifAlternative.motif.id )' - '$( $chosenMotifAlternative.motif.name )' with alternative '$( $chosenMotifAlternative.id )'"


#-----------------------------------------------
# IMPORT DATA
#-----------------------------------------------

$dataCsv = @( Import-Csv -Path $params.Path -Delimiter "`t" -Encoding UTF8 -Verbose )
Write-Log -message "Loaded '$( $dataCsv.count )' records"


#-----------------------------------------------
# PREPARE THE LINES
#-----------------------------------------------

# Use the first row for creating the lines template
Write-log -message "Rendering the lines:"
$lines = [array]@()
$firstRow = $dataCsv[0] 
$firstRow | Get-Member -MemberType NoteProperty | where { $_.Name -like "line#*" } | sort { $_.Name } | ForEach {
    $prop = $_.Name
    $line = $firstRow.$prop
    Write-log -message "    '$( $line )'"
    $lines += $line
}


#-----------------------------------------------
# PREPARE THE SIZE
#-----------------------------------------------

# TODO [ ] make the size adjustable through property

$size = $motifAlternative.raw.original_rect -split ", ",4
$width = $size[2]
$height = $size[3]

$inputwidth = 2000 # TODO [ ] put this maybe into settings
Write-log -message "Using $( $inputwidth ) width as reference for size calculation"
$sizes = Calc-Imagesize -sourceWidth $width -sourceHeight $height -targetWidth $inputwidth
Write-log -message "Calculated the the size of $( $sizes.width )x$( $sizes.height )"


#-----------------------------------------------
# CREATE THE JOB
#-----------------------------------------------

# Create the render job and get back the ids
# TODO [ ] split the uploads in parts of n records
Write-log -message "Creating a job for the image generation"
$picJob = $motifAlternative.createJob($dataCsv, $params.UrnFieldName, $lines, $sizes.width, $sizes.height, $false)


#-----------------------------------------------
# WAIT FOR THE JOB
#-----------------------------------------------

Write-log -message "Waiting for the job to finish"

#$picJob.updateStatus()
$picJob.autoUpdate()

<#
# Status can be CREATED, IN_PROGRESS, DONE, ERROR
{
    "JobId": "f5601144-a6d5-4008-b4be-1c3b3437f9e9",
    "Error": false,
    "Status": "IN_PROGRESS",
    "Key": "f81d4fae-7dec-11d0-a765-00a0c91e6bf6",
    "CDN": "http://cdn.alphapicture.com/f81d4fae-7dec-11d0-a765-00a0c91e6bf6/"
}
#>

# TODO [ ] wait until the job is kind of done 
if ( $settings.upload.waitForSuccess ) {

    $timeSpan = New-TimeSpan -Seconds $settings.upload.timeout
    Write-log -message "Asking for a maximum of $( $timeSpan ) seconds"

    # Initial wait of 5 seconds, so there is a good chance the messages are already send
    Write-log -message "Initial wait of 5 seconds"
    Start-Sleep -Seconds 5 # TODO [ ] put this into settings

    $stopWatch = [System.Diagnostics.Stopwatch]::new()
    $stopWatch.Start()
    do {
        # wait another n seconds
        Write-log -message "Checking current status of job: $( $picJob.status )"
        Start-Sleep -Seconds 10 # TODO [ ] put this into settings
    } until (( $picJob.status -eq "DONE" ) -or ( $stopWatch.Elapsed -ge $timeSpan ))
    
    Write-Log -message "Status of job: $( $picJob.status )"
    Write-log -message "Elapsed time: $( $stopWatch.Elapsed )"

}



#-----------------------------------------------
# CREATE LINKS FOR RECEIVERS
#-----------------------------------------------

$renderedPicLinks = [System.Collections.ArrayList]@()
$dataCsv | ForEach {

    $row = $_
    $urnFieldName = $params.UrnFieldName
    $commKeyFieldName = $params.CommunicationKeyFieldName
    $urn = $row.$urnFieldName
    
    [void]$renderedPicLinks.Add(
        [PSCustomObject]@{
            "Urn" = $row.$urnFieldName
            "Url" = "$( $picJob.raw.CDN )/ap_$( $urn ).jpg"
            "Motif" = $motifAlternative.raw.motif_id
            "Alternative" = $motifAlternative.raw.alternative_id
            "CommunicationKey" = $row.$commKeyFieldName
        }
    )
}

Write-Log -message "Created $( $renderedPicLinks.Count ) links"


#-----------------------------------------------
# EXPORT DATA
#-----------------------------------------------

$jobFile = "$( $uploadsFolder )\$( $picJob.JobId ).csv"
$renderedPicLinks | Export-Csv -Path $jobFile -Encoding UTF8 -NoTypeInformation -Delimiter "`t"
Write-Log -message "Created the file '$( $jobFile )'"


#-----------------------------------------------
# MERGE DATA IN SQLITE AND EXPORT
#-----------------------------------------------

<#
Steps:
Import existing csv
Insert into sqlite in memory database
Import data in this script into database
join and take the newest record per customer
read data and write as csv
FastStats picks up changed text file
#>

if ( $params.importFile ) {

    Write-Log -message "Trying to merge the current links with the existing links by URN"

    # Simply create the file, if it does not exist
    if (( Test-Path -Path $params.importFile ) -eq $false ) {
        
        Write-Log -message "File '$( $params.importFile )' does not exist. Creating it now!"
        $renderedPicLinks | select Urn, Url | Export-Csv -Path $params.importFile -Encoding UTF8 -NoTypeInformation -Delimiter "`t"

    # Merge the data and compare it
    } else {

        # Load existing file
        $existingRecords = @( import-csv -path $params.importFile -Delimiter "`t" -Encoding UTF8 )

        # Open up connection to new in-memory database
        # TODO [ ] put the dll path into settings
        sqlite-Load-Assemblies -dllFile "C:\Program Files\Apteco\FastStats Designer\sqlite-netFx46-binary-x64-2015-1.0.113.0\System.Data.SQLite.dll"
        $sqliteConnection = sqlite-Open-Connection -sqliteFile ":memory:" # "D:\data.sqlite"
        $sqliteCommand = $sqliteConnection.CreateCommand()
        $sqliteCommand.CommandText = @"
            CREATE TABLE IF NOT EXISTS "Data" (
                "key"	TEXT,
                "value"	TEXT
            );
"@
        $sqliteCommand.ExecuteNonQuery()
        Write-Log -message "Created temporary table"

        # Prepare data insertion and create a transaction
        # https://docs.microsoft.com/de-de/dotnet/standard/data/sqlite/bulk-insert
        $sqliteTransaction = $sqliteConnection.BeginTransaction()
        $sqliteCommand = $sqliteConnection.CreateCommand()
        $sqliteCommand.CommandText = "INSERT INTO data (key, value) VALUES (:key, :value)"
        Write-Log -message "Prepared the transaction for importing data"

        # Prepare data parameters
        $sqliteParameterKey = $sqliteCommand.CreateParameter()
        $sqliteParameterKey.ParameterName = ":key"
        [void]$sqliteCommand.Parameters.Add($sqliteParameterKey)

        $sqliteParameterValue = $sqliteCommand.CreateParameter()
        $sqliteParameterValue.ParameterName = ":value"
        [void]$sqliteCommand.Parameters.Add($sqliteParameterValue)

        Write-Log -message "Prepared parameters for the import"

        # Inserting the data with 1m records and 2 columns took 77 seconds
        $t = Measure-Command {

            # Insert the existing data
            $existingRecords | ForEach {
                $row = $_
                $sqliteParameterKey.Value = $row.Urn
                $sqliteParameterValue.Value = $row.Url
                [void]$sqliteCommand.ExecuteNonQuery()
            }

            # Insert the new data
            $renderedPicLinks | select Urn, Url | ForEach {
                $row = $_
                $sqliteParameterKey.Value = $row.Urn
                $sqliteParameterValue.Value = $row.Url
                [void]$sqliteCommand.ExecuteNonQuery()
            }

        }
        Write-Log -message "Inserted the data in $( $t.TotalSeconds ) seconds"

        # Commit the transaction
        $sqliteTransaction.Commit()
        Write-Log -message "Committed the data import"

        # Generate the query for merging data
        $mergedQuery = @"
            SELECT "key"
            ,"value"
        FROM (
            SELECT "key"
                ,"value"
                ,ROWID
                ,RANK() OVER (
                    PARTITION BY "key" ORDER BY ROWID DESC
                    ) rank
            FROM Data
            )
        WHERE rank = 1 AND key is not null
"@      

        # Query the merged result
        $t = Measure-Command {
            $updatedRecords = sqlite-Load-Data -sqlCommand $mergedQuery -connection $sqliteConnection
        }
        Write-Log -message "Queried the data in $( $t.TotalSeconds ) seconds"

        # Close the connection
        $sqliteConnection.Dispose()
        Write-Log -message "Closed the connection"

        # Write the file
        $updatedRecords | Select @{name="Urn";expression={ $_.key }}, @{name="Url";expression={ $_.value }} | Export-csv -Path $params.importFile -Encoding UTF8 -Delimiter "`t" -NoTypeInformation
        Write-Log -message "Updated the file '$( $params.importFile )'"

    }

} 



#-----------------------------------------------
# FINAL RESULTS
#-----------------------------------------------
<#
# Calculate results in total
$queued = $dataCsv.count
$sent = ( $sendsStatus | where { $_.lastStatus -eq "sent" } ).Count
$ignored = $sent - $queued

# Log the results
Write-Log -message "Imported '$( $dataCsv.Count  )' -> Queued '$( $sends.Count )' -> Already sent '$( $sent )' records in $( $t1.TotalSeconds   ) seconds "
#>

################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################
<#
If ( $sent -eq 0 ) {
    Write-Host "Throwing Exception because of 0 records"
    throw [System.IO.InvalidDataException] "No records were successfully uploaded"  
}
#>

# return object
$return = [Hashtable]@{

    # Mandatory return values
    "Recipients"= $renderedPicLinks.Count
    "TransactionId"=$processId

    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider"=$moduleName
    "ProcessId" = $processId

    # Some more information for the broadcasts script
    #"EmailFieldName"= $params.EmailFieldName
    #"Path"= $params.Path
    #"UrnFieldName"= $params.UrnFieldName

    # More information about the different status of the import
    #"RecipientsIgnored" = $ignored
    #"RecipientsQueued" = $queued
    #"RecipientsSent" = $sent

}

# return the results
$return