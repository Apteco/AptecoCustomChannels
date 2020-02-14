################################################
#
# NOTES
#
################################################

<#

#>


################################################
#
# FUNCTIONS
#
################################################

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
    return $currentTimestampResponse

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


Function Get-EpiSession {

    $sessionPath = "$( $settings.sessionFile )"
    
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

