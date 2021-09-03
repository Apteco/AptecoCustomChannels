
################################################
#
# GENERIC CLASSES AND ENUMS
#
################################################





################################################
#
# INHERITED CLASSES AND ENUMS
#
################################################

class MotifAlternative {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [int] $id
    [string] $name

    hidden [String] $nameConcatChar = " / "
    hidden [bool] $defaultUseWatermark = $false

    [Motif] $motif # parent element
    [PSCustomObject]$raw        # the raw source object for this one 
    

    #-----------------------------------------------
    # PUBLIC CONSTRUCTORS
    #-----------------------------------------------

    # empty default constructor needed to support hashtable constructor
    MotifAlternative () {

        $this.init()

    } 

    MotifAlternative ( [String]$inputString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        $this.init($inputString)

    }


    #-----------------------------------------------
    # HIDDEN CONSTRUCTORS - CHAINING
    #-----------------------------------------------


    [void] init () {
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

    }

    # Used for a minimal input
    [void] init ([String]$inputString ) {

        $this.init()

        $stringParts = $inputString -split [regex]::Escape($this.nameConcatChar.trim()),3
        $this.motif = [Motif]@{
            id = $stringParts[0].trim()
        }
        $this.id = $stringParts[1].trim()
        $this.name = $stringParts[2].trim()

    }

    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [String] toString() {
        $desc = "$( $this.motif.name ) - $( $this.id ) - $( $this.name )"
        return $this.motif.id, $this.id, $desc -join $this.nameConcatChar
    }

    # TODO [x] think about returning values, e.g. saving local or inline image
    [String]createSinglePicture([array]$lines, [int]$width, [int]$height, [bool]$useWatermark, [String]$outputFile, [bool]$returnBase64) {

        # Get alphapictures object
        $alpha = $this.motif.alphaPictures

        # Translate lines into object
        # TODO  [ ] check if there are more lines or characters than available
        $textLines = [PSCustomObject]@{}
        $maxLines = ( $this.raw.lines | Get-Member -MemberType NoteProperty | select name -Last 1 ).Name
        $i = 0
        $this.raw.lines | Get-Member -MemberType NoteProperty | ForEach {
            $lineNumber = $_.Name
            $maxCharsLine = $this.raw.lines.$lineNumber.length
            $currentLine = $lines[$i++]
            $lineText = ""
            if ( $currentLine.Length -gt 0 -and $null -ne $currentLine ) {
                $lineText = $currentLine
            }
            $textLines | Add-Member -MemberType NoteProperty -Name $lineNumber -Value $lineText
        }

        # Create body for the picture generation
        $body = [Ordered]@{
            MotifId = $this.motif.id    # Id of the motif
            AlternativeId = $this.id    # Alternative Id
            Lines = $textLines          # The text for the lines
            Dimensions = @{             # Pixel dimensions
                "w" = $width
                "h" = $height
            }
            <#
            "SourceRect" = @{ # Optional: SourceRect is for retrieving a certain cut-out of the original image
                "x1" = 1532
                "y1" = 1353
                "x2" = 3801
                "y2" = 2195
            }
            #>
            Watermark = $useWatermark   # Optional: set to true if image should be watermarked
        }

        # Call AlphaPictures
        $params = $alpha.defaultParams + @{
            uri = "$( $alpha.baseUrl)Image"
            method = "Post"
            body = ConvertTo-Json -InputObject $body -Depth 8
            outFile = $outputFile # TODO [x] make this more parametrised and also load picture inline for preview window
            returnBase64 = $returnBase64
        }
        $res = Invoke-AlphaPictures @params

        return $res
        
    }

    [String]createSinglePicture([array]$lines, [int]$width, [int]$height, [bool]$returnBase64) {
        $useWatermark = $this.defaultUseWatermark
        $res = $this.createSinglePicture($lines, $width, $height, $useWatermark, "", $returnBase64)
        return $res
    }

    [String]createSinglePicture([array]$lines, [int]$width, [int]$height, [String]$outputFile) {
        $useWatermark = $this.defaultUseWatermark
        $res = $this.createSinglePicture($lines, $width, $height, $useWatermark, $outputFile, $false)
        return $res
    }

    [String]createSinglePicture([array]$lines, [int]$width, [int]$height) {
        $res = $this.createSinglePicture($lines, $width, $height, "")
        return $res
    }

    [String]createSinglePicture([array]$lines, [String]$outputFile) {
        $size = $this.raw.original_rect -split ", ",4
        $width = $size[2]
        $height = $size[3]
        $res = $this.createSinglePicture($lines, $width, $height, $outputFile)
        return $res
    }

    [String]createSinglePicture([array]$lines, [bool]$returnBase64) {
        $size = $this.raw.original_rect -split ", ",4
        $width = $size[2]
        $height = $size[3]
        $res = $this.createSinglePicture($lines, $width, $height, $returnBase64)
        return $res
    }

    [String]createSinglePicture([array]$lines) {
        $res = $this.createSinglePicture($lines, "")
        return $res
    }

    [AlphaJobs]createJob([pscustomobject]$data, [String]$urnFieldName, [array]$lines, [int]$width, [int]$height, [bool]$useWatermark) {

        # Get alphapictures object
        $alpha = $this.motif.alphaPictures

        # Translate lines into object
        # TODO  [ ] check if there are more lines or characters than available
        $textLines = [PSCustomObject]@{}
        $maxLines = ( $this.raw.lines | Get-Member -MemberType NoteProperty | select name -Last 1 ).Name
        $i = 0
        $this.raw.lines | Get-Member -MemberType NoteProperty | ForEach {
            $lineNumber = $_.Name
            $maxCharsLine = $this.raw.lines.$lineNumber.length
            $currentLine = $lines[$i++]
            $lineText = ""
            if ( $currentLine.Length -gt 0 -and $null -ne $currentLine ) {
                $lineText = $currentLine
            }
            $textLines | Add-Member -MemberType NoteProperty -Name $lineNumber -Value $lineText
        }

        # Create body for the picture job generation
        $body = [PSCustomObject]@{
            "Images" = @( # Array of motifs that need to be rendered
                [Ordered]@{
                    "MotifId" = $this.motif.id
                    "AlternativeId" = $this.id
                    "Template" = $textLines # TODO [ ] implement support for syntax "1+2+3": "combined line with automatic line break"                        
                    "Filename" = "ap_%$( $urnFieldName )%" # Filename, without JPG extension # TODO [ ] add file prefix to settings
                    "Dimensions" = @{ # Dimensions in pixels
                        "w" = $width
                        "h" = $height
                    }
                    "Watermark" = $useWatermark
                }
            )
            #"Callback" = "http://some.callback.com/" # HTTP callback called when job done
            "OutputOptions" = @{ # This are options related to the output of this job
                "OutputMethod" = "HOTLINK" # HOTLINK|ZIP # TODO [ ] Add support for zip download
            }
            "Data" = $data.psobject.BaseObject
        }

        #$body | Add-Member -MemberType NoteProperty -Name "Data" -Value $data

        # Call AlphaPictures
        $params = $alpha.defaultParams + @{
            uri = "$( $alpha.baseUrl)Job"
            method = "Post"
            body = ConvertTo-Json -InputObject $body -Depth 8
        }
        $res = Invoke-AlphaPictures @params

        # Create job from this one
        $alphaJob = ( [AlphaJobs]@{
    
            "alphaPictures" = $this.motif.alphaPictures
            "raw" = $res
            "jobId" = $res.JobId
            "status" = $res.Status
        
        })

        $alpha.addJob( $alphaJob )

        return $alphaJob
        
    }

}

class Motif {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [int] $id
    [string] $name
    [DateTime]$created
    [DateTime]$updated
    [System.Collections.ArrayList]$alternatives
    
    hidden [String] $nameConcatChar = " / "

    hidden [AlphaPictures]$alphaPictures    # parent class
    [PSCustomObject]$raw        # the raw source object for this one 


    #-----------------------------------------------
    # PUBLIC CONSTRUCTORS
    #-----------------------------------------------

    # empty default constructor needed to support hashtable constructor
    Motif () {

        $this.init()

    } 
    

    Motif ( [String]$inputString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        $this.init($inputString)

    }

    #-----------------------------------------------
    # HIDDEN CONSTRUCTORS - CHAINING
    #-----------------------------------------------


    [void] init () {
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }
<#
        if ( $this.raw.alternatives ) {
            $this.raw.alternatives | ForEach {
                $alternative = $_
                [void]$this.$alternatives.add(
                    [MotifAlternative]@{
                        id = $alternative.id
                        name = $alternative.name
                        motif = $this
                        raw = $alternative
                    }
                )
            }
        }
#>
    }

    # Used for a minimal input
    [void] init ([String]$inputString ) {

        $this.init()

        $stringParts = $inputString -split [regex]::Escape($this.nameConcatChar.trim()),2
        $this.id = $stringParts[0].trim()
        $this.name = $stringParts[1].trim()

    }


    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [void] setAlternatives($alternatives) {
        $this.alternatives = [System.Collections.ArrayList]@()
        $this.addAlternatives($alternatives)
    }

    [void] addAlternatives($alternatives) {
        $alternatives | ForEach {
            $alternative = $_            
            [void]$this.alternatives.add(
                [MotifAlternative]@{
                    id = $alternative.alternative_id
                    name = $alternative.name
                    motif = $this
                    raw = $alternative
                }
            )
        }
    }

    [String] toString() {
        return $this.id, $this.name -join $this.nameConcatChar
    }

}


#-----------------------------------------------
# ALPHAPICTURES JOBS
#-----------------------------------------------

class AlphaJobs {


    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    hidden [AlphaPictures]$alphaPictures    # parent class
    [PSCustomObject]$raw        # the raw source object for this one 

    #[String]$outputFolder

    [String]$jobId

    [String]$status
    [DateTime]$startTime
    [DateTime]$endTime
    #[int]$offset = 0
    #hidden [int]$limit = 10000000 #10 #10000000 # TODO [ ] test limit
    [int]$totalSeconds = 0

    #hidden [String]$filename
    #hidden [String[]]$exportFiles
    hidden [Timers.Timer]$timer
    #[bool] $alreadyDownloaded = $false


    #-----------------------------------------------
    # PUBLIC CONSTRUCTORS
    #-----------------------------------------------

    # empty default constructor needed to support hashtable constructor
    AlphaJobs () {
        $this.init()
    } 

    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    hidden [void] init () {
        $this.startTime = [DateTime]::Now
    }

    #[String[]] getFiles() {
    #    return $this.exportFiles
    #}

    [void] updateStatus () {

        $body = @{
            "Id" = $this.jobId
        }

        $params = $this.alphaPictures.defaultParams + @{
            uri = "$( $this.alphaPictures.baseUrl )JobInfo"
            Method = "Post"
            Body = ConvertTo-Json -InputObject $body -Depth 8
        }

        $jobStatus = Invoke-AlphaPictures @params

        # An error happened
        If ( $jobStatus.error ) {

            # TODO [x] Maybe throw an exception here, the job errored, the message is in $jobsStatus.error and can be UNKNOWN_JOB or similar
            # TODO [ ] Include maybe writing to log or in the calling script
            throw [System.IO.InvalidDataException] "Error in Job: $( $jobStatus.error)"            

        # All fine
        } else {

            <#
            Getting back something like

            JobId    : 29b00856-216c-4499-97b0-9f1de317081b
            Error    :
            Status   : DONE
            Key      : 29b00856-216c-4499-97b0-9f1de317081b
            Progress : @{Total=4; Done=4; Percentage=100}
            CDN      : https://external.alphapicture.com/Result/29b00856-216c-4499-97b0-9f1de317081b
            #>

            #Write-Verbose ( $exportStatus | ConvertTo-Json )
            $this.status = $jobStatus.Status
            $this.raw = $jobStatus

            # Status can be CREATED, IN_PROGRESS, DONE, ERROR
            if ( $jobStatus.Status -in @("DONE","ERROR") ) {
                #$this.filename = $exportStatus.file_name
                $this.endTime =  [DateTime]::Now
                $t = New-TimeSpan -Start $this.startTime -End $this.endTime
                $this.totalSeconds = $t.TotalSeconds

                if ( $jobStatus.Status -eq "ERROR" ) {
                    throw [System.IO.InvalidDataException] "Error in Job: $( $jobStatus.Error )"
                }

            }

        }


    }

    #[void] autoUpdate() {
    #    $this.autoUpdate($false)
    #}

    [void] autoUpdate() {

        # Create a timer object with a specific interval and a starttime
        $this.timer = New-Object -Type Timers.Timer
        $this.timer.Interval  = 20000 # milliseconds, the interval defines how often the event gets fired
        $timerTimeout = 600 # seconds

        # Register an event for every passed interval
        Register-ObjectEvent -InputObject $this.timer  -EventName "Elapsed" -SourceIdentifier $this.jobId -MessageData @{ timeout=$timerTimeout; alphaJob = $this } -Action {
            
            # Input
            $alphaJob = $Event.MessageData.alphaJob

            # Calculate current timespan
            $timeSpan = New-TimeSpan -Start $alphaJob.startTime -End ( Get-Date )

            # Check current status
            $alphaJob.updateStatus()

            If ($alphaJob.status -in @("DONE","ERROR") ) { # -or ( $this.raw.type -eq "responses" -and $emarsysExport.status -eq "ready")

                $Sender.stop()

                #if ($Event.MessageData.downloadImmediatly) {
                #    $emarsysExport.downloadResult()
                #}

            }

            # Is timeout reached? Do something!            
            if ( $timeSpan.TotalSeconds -gt $Event.MessageData.timeout ) {

                # Stop timer now (it is important to do this before the next processes run)
                $Sender.Stop()
                Write-Host "Done! Timer stopped because timeout reached!"

            }

        } | Out-Null

        # Start the timer
        $this.timer.Start()

    }
    <#
    [void] downloadResult() {

        # TODO [ ] unregister timer event, if it exists

        # Download file
        # TODO [ ] implement offset and limit
        # TODO [ ] export contains multiple files
        # TODO [ ] calculate time when finishing export
        if ( @("ready","done") -contains $this.status ) {
            
            if ($this.raw.type -eq "contactlist") {
                $listCount = $this.list.count()
                $rounds = [Math]::Ceiling($listCount/$this.limit)
            } else {
                $rounds = 1
            }

            for ( $i = 0 ; $i -lt $rounds ; $i++ ) {
                # TODO [ ] it looks like there is a bug in offset and limit, so re-visit this later
                $offset = $i * $rounds

                # Sometimes the export does not come to the status "done" so we can download it with a fictitous filename
                #if ( $this.status -eq "ready" ) {
                #    $this.filename = "$( [DateTime]::Now.ToString("yyyyMMdd_HHmmss") ).csv"
                #}

                # Create the download job
                $params = $this.emarsys.defaultParams + @{
                    uri = "$( $this.emarsys.baseUrl )export/$( $this.exportId )/data" #?offset=$( $offset )&limit=$( $this.limit )"
                    outFile = "$( $this.outputFolder )\$( $this.filename )"
                }
                Invoke-emarsys @params

                # Add to the result
                $this.exportFiles += $params.OutFile
            }

            # Flag this as already downloaded
            $this.alreadyDownloaded = $true

        }
        
    }
    #>

}



################################################
#
# MAIN CLASS
#
################################################


class AlphaPictures {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    hidden [pscredential]$cred                 # holds the username and secret
    hidden [int]$waitSeconds = 10 
    [String]$baseUrl = "https://v4.alphapicture.com/"

    [String]$providerName = "alphapictures"

    [PSCustomObject]$defaultParams
    hidden [AlphaJobs[]]$jobs


    #-----------------------------------------------
    # PUBLIC CONSTRUCTORS
    #-----------------------------------------------

    AlphaPictures() {
        $this.init()
    }

    AlphaPictures ( [String]$username, [String]$secret ) {        
        $this.init( $username, $secret )
    }

    AlphaPictures ( [String]$username, [String]$secret, [String]$baseUrl ) {
        $this.init( $username, $secret, $baseUrl)
    }

    AlphaPictures ( [pscredential]$cred ) {
        $this.init( $cred )
    }

    AlphaPictures ( [pscredential]$cred, [String]$baseUrl ) {
        $this.init( $cred, $baseUrl )
    }


    #-----------------------------------------------
    # HIDDEN CONSTRUCTORS - CHAINING
    #-----------------------------------------------

    hidden [void] init () {

        $this.defaultParams = @{
            cred = $this.cred
        }

        if ( $script:settings.download.waitSecondsLoop ) {
            $this.waitSeconds = $script:settings.download.waitSecondsLoop
        }

    }

    hidden [void] init ( [String]$username, [String]$secret ) {
        $stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $secret ) -AsPlainText -Force
        $this.cred = [pscredential]::new( $username, $stringSecure )
        $this.init()
    }

    hidden [void] init ( [String]$username, [String]$secret, [String]$baseUrl ) {
        $this.baseUrl = $baseUrl
        $this.init( $username, $secret )
    }

    hidden [void] init ( [pscredential]$cred ) {
        $this.cred = $cred
        $this.init()
    }

    hidden [void] init ( [pscredential]$cred, [String]$baseUrl ) {
        $this.baseUrl = $baseUrl
        $this.init( $cred )
    }


    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [PSCustomObject] getMotifs () {

        # Call AlphaPictures
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)Motifs"
        }
        $res = Invoke-AlphaPictures @params
        
        # Transform result to objects
        $motifs = [System.Collections.ArrayList]@()
        $res | ForEach {

            $motif = $_

            $motifObj = [Motif]@{
                id = $motif.id
                name = $motif.name
                created = $motif.creationdate
                updated = $motif.lastmodified
                alphaPictures = $this
                raw = $motif
            }
            $motifObj.setAlternatives($motif.alternatives)

            [void]$motifs.Add($motifObj)

        }

        return $motifs
  
    }

    [void] addJob ([AlphaJobs]$job) {
        #if ( -not ($this.jobs.Count -gt 0) ) {
        #    $this.jobs = [System.Collections.ArrayList]@()
        #}
        $this.jobs += $job
    }

    [AlphaJobs[]] getJobs () {
        return $this.jobs
    }

}




################################################
#
# OTHER FUNCTIONS
#
################################################

Function Invoke-AlphaPictures {

    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$false)][pscredential]$cred                                   # securestring containing username as user and secret as password
        ,[Parameter(Mandatory=$false)][System.Uri]$uri = "https://v4.alphapicture.com/"  # default url to use
        ,[Parameter(Mandatory=$false)][String]$method = "Get"
        ,[Parameter(Mandatory=$false)][String]$outFile = ""
        ,[Parameter(Mandatory=$false)][System.Object]$body = $null
        ,[Parameter(Mandatory=$false)][bool]$returnBase64 = $false
    )

    begin {

        #-----------------------------------------------
        # AUTH
        #-----------------------------------------------
        
        $password = $cred.GetNetworkCredential().Password
        $account = $cred.UserName


        #-----------------------------------------------
        # HEADER
        #-----------------------------------------------

        $contentType = "application/json;charset=utf-8"

        $headers = @{
            "APIV4-Account" = $account
            "APIV4-Password" = $password
        }

    }

    process {

        $params = @{
            Uri = $uri
            Method = $method
            Verbose = $true
            Headers = $headers
            ContentType = $contentType
        }

        if ( $body -ne $null ) {
            $params += @{
                "Body" = $body
            }
        }

        if ( $outFile -ne "" ) {
            $params += @{
                "OutFile" = $outFile
            }
        }

        if ( $returnBase64 ) {

            $params += @{
                "UseBasicParsing" = $true
            }
            
            $response = Invoke-WebRequest @params
            # From PS 6 onwards, use  bytestream instead: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/set-content?view=powershell-7.2            
            #set-content -Value $response.content -Path ".\test8.png" -Encoding Byte
            $result = [Convert]::ToBase64String( $response.content )

        } else {

            try {

                $result = Invoke-RestMethod @params
            
            } catch {
    
                ParseErrorForResponseBody -err $_
                # TODO [ ] Do something with the error
    
            }

        }

    }

    end {

        if ( $outFile -ne "" ) {

            $outFile

        } else {           
            
            $result

        }

    }

}

<#
Calc-Imagesize -sourceWidth 1250 -sourceHeight 500 -targetWidth 500
Calc-Imagesize -sourceWidth 1250 -sourceHeight 500 -targetHeight 500
#>

function Calc-Imagesize {

    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$true)][int]$sourceWidth
        ,[Parameter(Mandatory=$true)][int]$sourceHeight
        ,[Parameter(Mandatory=$false)][int]$targetWidth = 0
        ,[Parameter(Mandatory=$false)][int]$targetHeight = 0
    )
    
    begin {

        # Check if target width or height is available
        if ( $targetWidth -gt 0 -or $targetHeight -gt 0 ) {
            #"Check is good, proceed"
        } else {
            throw [System.IO.InvalidDataException] "No target width or height available, please change call"
        }

        # Calculate image ratio
        $ratio = $sourceWidth/$sourceHeight

    }
    
    process {
        
        if ( $targetWidth -gt 0 ) {
            $width = $targetWidth
            $height = $targetWidth / $ratio
        } else {
            $width = $targetHeight * $ratio
            $height = $targetHeight
        }

    }
    
    end {

        #return 
        [PSCustomObject]@{
            width = [Math]::Round($width)
            height = [Math]::Round($height)
        }

    }
}