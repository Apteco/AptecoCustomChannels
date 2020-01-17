################################################
#
# SCRIPT ROOT
#
################################################
<#
# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}


Set-Location -Path $scriptPath
#>

Add-Type -TypeDefinition @"
   public enum EpiResponseTypes
   {
      Recipients,
      Opens,
      Clicks,
      Responses,
      Unsubscribes,
   }
"@


Function Get-EpiResponses {

    param(
         [Parameter(Mandatory=$true)][EpiResponseTypes]$responseType
        ,[Parameter(Mandatory=$true)][int]$maxDays = 30 # max on episerver is 30 days since dispatch
        ,[Parameter(Mandatory=$false)][int]$maxRowsPerPage = 1000 # max on episerver are 1000 rows per call
    )
    
    # settings
    $maxRows = $maxRowsPerPage
    $currentTimestamp = Get-Unixtime -inMilliseconds
    $secondsForXDays = $maxDays * 60*60*24*1000

    # switch
    Switch ( $responseType ) {
        "Recipients" {
            $endpoint = "getRecipients"
        }
        "Opens" {
            $endpoint = "getOpens"
        }
        "Clicks" {
            $endpoint = "getClicks"
        }
        "Responses" {
            $endpoint = "getResponses"
        }
        "Unsubscribes" {
            $endpoint = "getUnsubscribes"
        }
    }

    # get first row to see how many columns a row has
    $firstRow = Invoke-Epi -webservice "ClosedLoop" -method $endpoint -param @(($currentTimestamp - $secondsForXDays),$currentTimestamp,@{value=0;datatype="int"},@{value=1;datatype="int"}) -useSessionId $true #-verboseCall
    $noOfColumns = $firstRow."get$( $responseType )Return".Count

    # page through rows
    $page = 1    
    $rows = @()
    do {
    
        # get data
        $start = ($page*$maxRows)-$maxRows
        $rowsForXDays = Invoke-Epi -webservice "ClosedLoop" -method $endpoint -param @(($currentTimestamp - $secondsForXDays),$currentTimestamp,@{value=$start;datatype="int"},@{value=$maxRows;datatype="int"}) -useSessionId $true #-verboseCall

        $j = 0
        $i = 0
        $rowsForXDays."get$( $responseType )Return" | ForEach {
            
            $rec = $_

            if ( $i % $noOfColumns -eq 0 ) {
                $row = New-Object PSCustomObject
                $j = 0
            }
 
            $row | Add-Member -MemberType NoteProperty -Name "Col$( $j )" -Value $rec
            $i += 1
            $j += 1

            if ( $i % $noOfColumns -eq 0 ) {
                $rows += $row
            }

        }
    
        # preparation for next page
        $page += 1

    } until ( 1 -eq 1 -or $rowsForXDays."get$( $responseType )Return".Count -lt ( $maxRows * $noOfColumns )  )

    # return all rows
    return $rows

}

# Get current time set in EpiServer campaign which is a unixtime in milliseconds
Function Get-EpiTime {

    [long]$currentTimestampResponse = Invoke-Epi -webservice "ClosedLoop" -method "getCurrentTime" -param @() -useSessionId $true
    return $currentTimestamp

}

# current unixtimestamp with the optional milliseconds
Function Get-Unixtime {
    
    param(
        [Parameter(Mandatory=$false)][switch] $inMilliseconds = $false
    )

    $multiplier = 1

    if ( $inMilliseconds ) {
        $multiplier = 1000
    }

    [long]$unixtime = [double]::Parse((Get-Date(Get-Date).ToUniversalTime() -UFormat %s)) * $multiplier

   return $unixtime 

}

Function Count-Dimensions {

    param(
        [Parameter(Mandatory=$true)]$var 
    )

    $return = 0
    if ( $var -is [array] ) {
        $add = Count-Dimensions -var $var[0]
        $return = $add + 1
    } 

    return $return

}

Function Is-Numeric {

    param(
        [Parameter(Mandatory=$true)]$Value
    )

    return $Value -match "^[\d\.]+$"
}

Function Format-SoapParameter {

    param(
         [Parameter(Mandatory=$true)]$var
        ,[Parameter(Mandatory=$true)]$paramIndex
    )

    $noDimensions = Count-Dimensions -var $var
    $xml = Switch ( $noDimensions ) {

    0 {
        
        # TODO [ ] this does not work right for decimals, but they are not needed at the moment because the SOAP only uses strings and longs
        if (Is-Numeric $var) {
            $datatype = "long"
            $value = $var
        } elseif ( $var -is "System.Collections.Hashtable" ) {
            $datatype = $var.datatype
            $value = $var.value
        } else {
            $datatype = "string"
            $value = $var
        }
                
@"
<in$( $paramIndex ) xsi:type="xsd:$( $datatype )">$( $value )</in$( $paramIndex )>
"@

    }

    1 {
    
@"
<in$( $paramIndex ) SOAP-ENC:arrayType="xsd:string[$( $var.Count )]" xsi:type="ArrayOf_xsd_string">$( $var | ForEach {                
    "`n    <item xsd:type=""xsd:string"">$( $_ )</item>"                
})
</in$( $paramIndex )>
"@
            
    }

    2 {
    
@"
<in$( $paramIndex ) SOAP-ENC:arrayType="xsd:string[][$( $var.Count )]" xsi:type="ArrayOfArrayOf_xsd_string">$($var | ForEach {
    "`n    <item SOAP-ENC:arrayType=""xsd:string[$( $_.Count )]"" xsi:type=""SOAP-ENC:Array"">$( $_ | ForEach {
        "`n        <item xsd:type=""""xsd:string"""">$( $_ )</item>"
    } )`n    </item>"
} )
</in$( $paramIndex )>
"@

    }

}

    return $xml

}

Function Get-EpiRecipientLists {

    param()

    <#
    $recipientListIDs = Invoke-Epi -webservice "RecipientList" -method "getAllIds" -param @() -useSessionId $true

    $recipientLists = @()
    $recipientListIDs | ForEach {

        $recipientListID = $_

        # create new object
        $recipientList = New-Object PSCustomObject
        $recipientList | Add-Member -MemberType NoteProperty -Name "ID" -Value $recipientListID

        # ask for name
        $recipientListName = Invoke-Epi -webservice "RecipientList" -method "getName" -param @(@{value=$recipientListID;datatype="long"}) -useSessionId $true
        $recipientList | Add-Member -MemberType NoteProperty -Name "Name" -Value $recipientListName

        # ask for description
        $recipientListDescription = Invoke-Epi -webservice "RecipientList" -method "getDescription" -param @(@{value=$recipientListID;datatype="long"}) -useSessionId $true
        $recipientList | Add-Member -MemberType NoteProperty -Name "Description" -Value $recipientListDescription

        $recipientLists += $recipientList

    }#>

    $columns = Invoke-Epi -webservice "RecipientList" -method "getColumnNames" -param @() -useSessionId $true
    $dataset = Invoke-Epi -webservice "RecipientList" -method "getDataSet" -param @() -useSessionId $true

    # load lists into table
    $rows = @()
    for ($i = $columns.Count; $i -lt $dataset.getDataSetReturn.Count ; $i = $i + $columns.Count) {
    
        $row = New-Object PSCustomObject 

        for ( $j = 0; $j -lt $columns.Count; $j+=1 ) {
               
            $row | Add-Member -MemberType NoteProperty -Name $columns[$j] -Value $dataset.getDataSetReturn[$i+$j]

        }

        $rows += $row

    }

    # check if counts are valid
    $counts = Invoke-Epi -webservice "RecipientList" -method "getCount" -param @(@{value="true";datatype="boolean"}) -useSessionId $true
    if ( $counts -eq $rows.Count ) {
        # counts are valid!
        # TODO [ ] add log entry here
    }

    return $rows

}

Function Invoke-Epi {

    param(
         [Parameter(Mandatory=$true)][String]$webservice
        ,[Parameter(Mandatory=$true)][String]$method
        ,[Parameter(Mandatory=$false)]$param = @()
        ,[Parameter(Mandatory=$false)][Boolean]$useSessionId = $false
        ,[Parameter(Mandatory=$false)][switch]$verboseCall = $false
        
    )

    $tries = 0
    Do {
        try {
            
            

            if ( $useSessionId ) {
                
                # decrypt secure string
                if ( $settings.encryptToken ) {
                    $sessionId = Get-SecureToPlaintext -String $Script:sessionId
                }

                if ($tries -eq 1) {
                    Write-Host "Refreshing session"
                    # replace $sessionId
                    $param[0] = $sessionId
                } else {
                    # put session in params first place
                    $param = ,$sessionId + $param
                }

                
            }

            $paramXML = ""
            for( $i = 0 ; $i -lt $param.count ; $i++ ) {
                
                $paramXML += Format-SoapParameter -var $param[$i] -paramIndex $i

            }

            $soapEnvelopeXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="urn:api.broadmail.de/soap11/Rpc$( $webservice )" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <SOAP-ENV:Body>
        <$( $method )>
            $( $paramXML )
        </$( $method )>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
"@
            #if ( $verboseCall ) {
                Write-Host $soapEnvelopeXml
            #}

            $header = @{
                "SOAPACTION" = $method
            }

            $contentType = "text/xml;charset=""utf-8"""
            #write-host $tries
            #write-host $response
            $response = Invoke-RestMethod -Uri "$( $settings.base )$( $webservice )" -ContentType $contentType -Method Post -Verbose -Body $soapEnvelopeXml -Headers $header

        } catch {
            Write-Host $_.Exception
            #If ($_.Exception.Response.StatusCode.value__ -eq "500") {
                Get-EpiSession
            #}
        }
    } until ($tries++ -eq 1 -or $response) # this gives us one retry

    #if ( $verboseCall ) {
        write-host $response.OuterXml
    #}
    
    $return = $response.Envelope.Body."$( $method )Response"."$( $method )Return"

    return $return

}

Function Get-PlaintextToSecure {

    param(
         [Parameter(Mandatory=$true)][String]$String
    )
    
    # generate salt
    Create-KeyFile -keyfilename "aes.key" -byteLength 32
    $salt = Get-Content -Path "aes.key" -Encoding UTF8

    # convert
    $stringSecure = ConvertTo-secureString -String $String -asplaintext -force
    $return = ConvertFrom-SecureString $stringSecure -Key $salt

    # return
    $return

}

Function Get-SecureToPlaintext {

    param(
         [Parameter(Mandatory=$true)][String]$String
    )

    # generate salt
    $salt = Get-Content -Path "aes.key" -Encoding UTF8

    #convert 
    $stringSecure = ConvertTo-SecureString -String $String -Key $salt
    $return = (New-Object PSCredential "dummy",$stringSecure).GetNetworkCredential().Password

    #return
    $return

}

Function Create-KeyFile {
    
    param(
         [Parameter(Mandatory=$false)][string]$keyfilename = "aes.key"
        ,[Parameter(Mandatory=$false)][int]$byteLength = 32
    )

    $keyfile = ".\$( $keyfilename )"
    
    # file does not exist -> create one
    if ( (Test-Path -Path $keyfile) -eq $false ) {
        $Key = New-Object Byte[] $byteLength   # You can use 16, 24, or 32 for AES
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
        $Key | Set-Content -Encoding UTF8 -Path $keyfile
    }
    
    
}

Function Get-EpiSession {

    $sessionPath = "$( $scriptPath )\$( $settings.sessionFile )"
    
    # if file exists -> read it and check ttl
    $createNewSession = $true
    if ( (Test-Path -Path $sessionPath) -eq $true ) {

        $sessionContent = Get-Content -Encoding UTF8 -Path $sessionPath | ConvertFrom-Json
        
        $expire = [datetime]::ParseExact($sessionContent.expire,"yyyyMMddHHmmss",[CultureInfo]::InvariantCulture)

        if ( $expire -gt [datetime]::Now ) {

            $createNewSession = $false
            $Script:sessionId = $sessionContent.sessionId
            
        }

    }
    
    # file does not exist or date is not valid -> create session
    if ( $createNewSession -eq $true ) {
        
        $expire = [datetime]::now.AddMinutes($settings.ttl).ToString("yyyyMMddHHmmss")

        $pass = Get-SecureToPlaintext $settings.login.pass
        $login = Invoke-Epi -webservice "Session" -method "login" -param @($settings.login.mandant, $settings.login.user, $pass)
        $sessionId = $login
        
        if ( $settings.encryptToken ) {
            $Script:sessionId = Get-PlaintextToSecure -String $sessionId
        } else {
            $Script:sessionId = $sessionId
        }

        $session = @{
            sessionId=$Script:sessionId
            expire=$expire
        }
        $session | ConvertTo-Json | Set-Content -Encoding UTF8 -Path $sessionPath
    
    
    }

    
    
}


Function rewriteFileAsParts() {

    param(
        [Parameter(Mandatory=$true)][string]$inputPath,
        [Parameter(Mandatory=$true)][int]$inputEncoding,
        [Parameter(Mandatory=$true)][int]$outputEncoding,
        [Parameter(Mandatory=$false)][int]$skipFirstLines,
        [Parameter(Mandatory=$false)][int]$writeCount = 0

    )

    $input = Get-Item -Path $inputPath
    $now = [datetime]::Now.ToString("yyyyMMddHHmmss")
    $tmpFile = "$( $input.FullName ).$( $now ).part"
    $append = $false # the true means to "append", false means replace

    # open file
    $reader = New-Object System.IO.StreamReader($input.FullName, [System.Text.Encoding]::GetEncoding($inputEncoding))
    
    # skip lines
    for ($i = 0; $i -lt $skipFirstLines; $i++) {
        $reader.ReadLine() > $null # Skip first line.
    }

    # write file
    $i = 0
    $j = 0
    while ($reader.Peek() -ge 0) {
        if ( $i%$writeCount -eq 0 ) {
            $f = "$( $tmpFile )$( $j )"
            if($writer.BaseStream) { $writer.Close() }
            $writer = New-Object System.IO.StreamWriter($f, $append, [System.Text.Encoding]::GetEncoding($outputEncoding)) 
            $j++
        }
        $writer.writeline($reader.ReadLine())


        <#
        # tipp for handling quotes

        if ($useEscapeQuotes) {
            $delimiter = """$( $delimiter )"""
            $preAndSuffix = """"    
        } else {
            $preAndSuffix = ""
        }
        $line = $preAndSuffix + $line + $delimiter + $appendValues + $preAndSuffix
        
        # parse and operations on line

        $line = $reader.ReadLine()                      # Read line
        $line = [Regex]::Replace($line,'"', "")         # Remove quotes            
        $items = $line.Split(",")                       # String -> Array by delimiter
        $line = $items -join ";"                        # Join items together again
        #$items \w
        #$items = [Regex]::Split($line,",")
        #$line = [String]::Join($items,";")
        #[String]:: $line
        #$line = [Regex]::Replace($line,",", ";")
        $writer.writeline($line)


        #>


        $i++
    }
    $writer.Close()
    $reader.Close()
    


}



Function Check-Path {

    param(
        [Parameter(Mandatory=$false)][string]$Path
    )

    $b = $false

    try {
        $b = Test-Path -Path $Path
    } catch [System.Exception] {
        #$errText = $_.Exception
        #$errText | Write-Output
        #"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tError: $( $errText )" >> $logfile        
        #$b = $false
    }

    return $b

}


Function Split-File {
    
    param(
         [Parameter(Mandatory=$true)][string]$inputPath # file to split
        ,[Parameter(Mandatory=$true)][string]$inputDelimiter # delimiter for input
        ,[Parameter(Mandatory=$true)][string]$outputDelimiter # delimiter for output
        ,[Parameter(Mandatory=$false)][int]$writeCount = -1 # think of -1 for one file or x > 0 for n records per file; NOTE: The writer cannot write more than the batchsize
        ,[Parameter(Mandatory=$false)][int]$batchSize = 200000 # read n records at once
        ,[Parameter(Mandatory=$false)][int]$chunkSize = 5000 # parse n records at once
        ,[Parameter(Mandatory=$false)][int]$throttleLimit = 20 # max nr of threads to work in parallel for parsing
        ,[Parameter(Mandatory=$false)][bool]$header = $true # file has a header?
        ,[Parameter(Mandatory=$false)][bool]$writeHeader = $true # output the header
        ,[Parameter(Mandatory=$false)][string[]]$outputColumns = @() # columns to output
        ,[Parameter(Mandatory=$false)][string[]]$outputDoubleQuotes = $false # output double quotes 

    )

    # TODO [ ] test files without header
    # TODO [ ] put encodings in parameter

    # NOTE: Because the writing is in the same loop as reading a batch, $writecount cannot be larger than $batchsize

    # settings
    $now = [datetime]::Now.ToString("yyyyMMddHHmmss")
    #$tmpFile = "$( $input.FullName ).$( $now ).part"

    # counter initialisation
    $batchCount = 0 #The number of records currently processed for SQL bulk copy
    $recordCount = 0 #The total number of records processed. Could be used for logging purposes.
    $intLineReadCounter = 0 #The number of lines read thus far
    $fileCounter = 0

    # import settings
    $inputEncoding = [System.Text.Encoding]::UTF8.CodePage

    # open file to read
    $input = Get-Item -path $inputPath    
    $reader = New-Object System.IO.StreamReader($input.FullName, [System.Text.Encoding]::GetEncoding($inputEncoding))

    # export settings
    $exportId = [guid]::NewGuid()
    $exportFolder = New-Item -Name $exportId -ItemType "directory" # create folder for export
    $exportFilePrefix = "$( $exportFolder.FullName )\$( $input.Name )"
    $append = $true
    $outputEncoding = [System.Text.Encoding]::UTF8.CodePage

    # add extension to file prefix dependent on number of export files
    if ( $writeCount -ne -1 ) {
        $exportFilePrefix = "$( $exportFilePrefix ).part"
    }

    # read header if needed
    if ( $header ) {
        $headerRow = $reader.ReadLine()
    }


    # measure how much time is consumed
    #Measure-Command {
        
        # read lines until they are available
        while ($reader.Peek() -ge 0) {
                       
            #--------------------------------------------------------------
            # read n lines
            #--------------------------------------------------------------
            
            # create empty array with max of batchsize
            $currentLines = [string[]]::new($batchSize)

            # read n lines into the empty array
            # until batchsize or max no of records reached
            do 
            {
                $currentLines[$intLineReadCounter] = $reader.ReadLine()
                $intLineReadCounter += 1
                $recordCount += 1
            } until ($intLineReadCounter -eq $batchSize -or $reader.Peek() -eq -1)
            #$intLineReadCounter
            $batchCount += 1

            "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tbatchcount $( $batchCount )" >> $logfile
            "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`trecordCount $( $recordCount )" >> $logfile
            "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tintLineReadCounter $( $intLineReadCounter )" >> $logfile

            #--------------------------------------------------------------
            # parse lines sequentially
            #--------------------------------------------------------------
            
            <#
            $currentLines | ForEach {
                $line = $_                                      # Read line
                #$line = [Regex]::Replace($line,'"', "")         # Remove quotes            
                $items = $line.Split(";")  

            }
            #>

            #--------------------------------------------------------------
            # define line blocks (chunks) to be  parsed in parallel
            #--------------------------------------------------------------

            $chunks = @()
            $maxChunks = [Math]::Ceiling($intLineReadCounter/$chunkSize)            
            $end = 0

            "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tmaxChunks $( $maxChunks )" >> $logfile

            for($i = 0; $i -lt $maxChunks ; $i++) {
                $start = $i * $chunkSize 
                $end = $start+$chunkSize-1               
                if ( $end -gt $intLineReadCounter ) {
                    $end = $intLineReadCounter-1
                }
                #"$( $start ) - $( $end )"
                if ( $header ) {
                    $chunks += ,( @($headerRow) + @($currentLines[$start..$end]) )
                } else {
                    $chunks += ,@($currentLines[$start..$end])
                }
                
            }

            # log
            "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tchunks $( $chunks.Count )" >> $logfile
            for($i = 0; $i -lt $chunks.Count ; $i++) {
                "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tchunk $( $i ) size: $( $chunks[$i].Count - [int]$header )" >> $logfile # subtract one line if a header is included
            }
            #$chunks[0] | Out-File -FilePath "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") ).csv" -Encoding utf8 # write out some chunks to check

            #--------------------------------------------------------------
            # define scriptblock to parse line blocks in parallel
            #--------------------------------------------------------------

            $scriptBlock = {

                Param (
                    $parameters
                )

                $chunk = $parameters.chunk
                $header = $parameters.header # $true if the chunk is the header
                $inputDelimiter = $parameters.inputDelimiter
                $outputDelimiter = $parameters.outputDelimiter
                $outputCols = $parameters.outputColumns
                $outputDoubleQuotes = $parameters.outputDoubleQuotes

                # read input, convert to output
                $inputlines =  $chunk | ConvertFrom-Csv -Delimiter $inputDelimiter
                $outputlines = $inputlines | Select $outputCols | ConvertTo-Csv -Delimiter $outputDelimiter -NoTypeInformation
                
                # remove double quotes, tributes to https://stackoverflow.com/questions/24074205/convertto-csv-output-without-quotes
                if ( $outputDoubleQuotes -eq $false ) {
                    $outputlines = $outputlines | % { $_ -replace  `
                            "\G(?<start>^|$( $outputDelimiter ))((""(?<output>[^,""]*?)""(?=$( $outputDelimiter )|$))|(?<output>"".*?(?<!"")("""")*?""(?=$( $outputDelimiter )|$))|(?<output>))",'${start}${output}'} 
                            # '\G(?<start>^|,)(("(?<output>[^,"]*?)"(?=,|$))|(?<output>".*?(?<!")("")*?"(?=,|$))|(?<output>))','${start}${output}'} 
                }

                # result to return

                if ($header) {
                    $returnLines = $outputlines | Select -SkipLast 1
                } else {
                    $returnLines = $outputlines | Select -Skip 1
                }                

                $res = @{
                    lines = $returnLines
                    header = $header
                }                
                return $res

            }

            #--------------------------------------------------------------
            # create and execute runspaces to parse in parallel
            #--------------------------------------------------------------

            "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tPrepare runspace pool with throttle of $( $throttleLimit ) threads in parallel" >> $logfile

            $RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $throttleLimit)
            $RunspacePool.Open()
            $Jobs = @()

            # insert header "chunk" at first place
            if ( $header -and $batchCount -eq 1 ) { 
                
                $headerChunk = ,@($headerRow,$headerRow)
                $chunks = $headerChunk + $chunks
                
            }             
            
            "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tStarting runspace pool" >> $logfile

            $jobCount = 0
            $chunks | ForEach {
                
                $chunk = $_
                
                if ( $header -and $batchCount -eq 1 -and $jobCount -eq 0) {
                    $headerChunk = $true
                } else {
                    $headerChunk = $false
                }
                
                $arguments = @{            
                    chunk = $chunk
                    header = $headerChunk
                    inputDelimiter = $inputDelimiter
                    outputDelimiter = $outputDelimiter
                    outputColumns = $outputColumns
                    outputDoubleQuotes = $outputDoubleQuotes
                }
                
                $Job = [powershell]::Create().AddScript($scriptBlock).AddArgument($arguments)
                $Job.RunspacePool = $RunspacePool
                $Jobs += New-Object PSObject -Property @{
                    RunNum = $_
                    Pipe = $Job
                    Result = $Job.BeginInvoke()
                }
                
                $jobcount += 1

            }

            "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tChecking for results of $( $jobcount ) jobs" >> $logfile

            # check for results
            Write-Host "Waiting.." -NoNewline
            Do {
               Write-Host "." -NoNewline
               Start-Sleep -Milliseconds 500
            } While ( $Jobs.Result.IsCompleted -contains $false)
            Write-Host "All jobs completed!"
            
            # put together results
            $rows = @()
            ForEach ($Job in $Jobs) {
                $res = $Job.Pipe.EndInvoke($Job.Result)
                
                # put header always in first place ( could be in another position regarding parallelisation )
                if ( $res.header ) {
                    $headerRowParsed = $res.lines
                    #$rows = $rows + $res.lines  
                } else {
                    $rows += $res.lines  
                }
                              
            }

            "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tGot results back from $( $jobCount )" >> $logfile


            #--------------------------------------------------------------
            # write lines in file
            #--------------------------------------------------------------
            
            
            # open file if it should written in once
            if ( $writeCount -eq -1 ) {
                "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tOpen file to write: $( $exportFilePrefix )" >> $logfile
                $writer = New-Object System.IO.StreamWriter($exportFilePrefix, $append, [System.Text.Encoding]::GetEncoding($outputEncoding))
                if ($writeHeader) {
                    "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tWriting header" >> $logfile
                    $writer.WriteLine($headerRowParsed)
                }
            }

            "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tWriting $( $rows.count ) lines" >> $logfile

            # loop for writing lines
            $exportCount = 0          
            $rows | ForEach {         

                # close/open streams to write
                if ( ( $exportCount % $writeCount ) -eq 0 -and $writeCount -gt 0 ) {
                    if ( $null -ne $writer.BaseStream  ) {
                        "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tClosing file $( $fileCounter ) after exported $( $exportCount )" >> $logfile
                        $writer.Close() # close file if stream is open
                        $fileCounter += 1
                    }
                    $f = "$( $exportFilePrefix )$( $fileCounter )"
                    "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tOpen file to write: $( $f )" >> $logfile
                    $writer = New-Object System.IO.StreamWriter($f, $append, [System.Text.Encoding]::GetEncoding($outputEncoding))
                    if ($writeHeader) {
                        "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tWriting header" >> $logfile
                        $writer.WriteLine($headerRowParsed)
                    }
                }

                # write line
                $writer.writeline($_)

                # count the line
                $exportCount += 1

            }

            # close last file
            "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tClosing file $( $fileCounter ) after exported $( $exportCount )" >> $logfile
            $writer.Close()
            $fileCounter += 1


            #--------------------------------------------------------------
            # reset some values for the loop
            #--------------------------------------------------------------

            $intLineReadCounter = 0; #reset for next pass
            $currentLines.Clear()
            


        }
    #}

    $reader.Close()

    return $exportId.Guid

}

<#
# TEST
Set-Location -Path "C:\Users\Florian\Desktop\20190708\episerver"
$cols = @("message","urn","firstname","lastname")
#$cols = @("urn")
Split-File -inputPath "C:\Users\Florian\Desktop\20190708\episerver\Email_utf8.csv" -batchSize 50000 -chunkSize 5000 -writeCount 20000 -throttleLimit 20 -header $true -writeHeader $true -inputDelimiter "," -outputDelimiter "`t" -outputColumns $cols
#>



