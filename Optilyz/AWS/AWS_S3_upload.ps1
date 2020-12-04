Param(
    $operation,
    $uploadfile,
    $uploadfolder,
    $uploadfilename
)




<#########################

LINKS

#########################>

<#


resource: https://devops.profitbricks.com/api/s3/
https://gist.github.com/chrismdp/6c6b6c825b07f680e710
https://gist.github.com/tabolario/93f24c6feefe353e14bd
https://docs.aws.amazon.com/general/latest/gr/signature-v4-examples.html
http://czak.pl/2015/09/15/s3-rest-api-with-curl.html


TODO activate optional encryption https://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectPUT.html

TODO setup lifecycle by prefix

#>

#$operation = "UPLOADFILE" # LISTBUCKETS, LISTFILES, DOWNLOADFILE, UPLOADFILE, CREATEFOLDER

<#########################

SETTINGS
already prepared for profitbricks

#########################>

$accessKey = Get-SecureToPlaintext $settings.aws.accessKey # enter your access key
$secretKey = Get-SecureToPlaintext $settings.aws.secretKey # enter the secret key
$region = $settings.aws.region
$service = $settings.aws.service
[System.Uri]$endpoint = $settings.aws.endpoint



<#########################

OPERATION SETTINGS

#########################>

# Default values
$verb = "GET"
$fileName = ""
$contentType = "text/plain"
$contentHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" #empty string

switch ($operation) {

    "LISTBUCKETS" {       
       
        $bucket = ""
        break

    }
    
    "LISTFILES" {

        $bucket = "apteco.campaign-automation.de"
        break

    }
    
    "DOWNLOADFILE" {
        
        $bucket = "publish"
        $contentType = "application/zip"
        $fileName = #"Writemonkey3-windows-64bit-beta4-sep2017.zip"
        $targetFile = "C:\Users\Florian\Desktop\20180411\201804 powershell s3 profitbricks\Writemonkey3-windows-64bit-beta4-sep2017.zip"
        break

    }
    
    "UPLOADFILE" {

        # TODO implement MD5 checksum
        # TODO check server side encryption
        # TODO multipart sometime...
        
        <#
        https://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectPUT.html
        To ensure that data is not corrupted traversing the network, use the Content-MD5 header. When you use this header,
        Amazon S3 checks the object against the provided MD5 value and, if they do not match, returns an error. Additionally,
        you can calculate the MD5 while putting an object to Amazon S3 and compare the returned ETag to the calculated MD5 value. 
        find out content type https://gallery.technet.microsoft.com/scriptcenter/PowerShell-Function-to-6429566c
        #>

        $verb = "PUT"
        $bucket = "apteco.campaign-automation.de"        
        
        # 2:18 für upload von 20MB
        $contentType = "text/plain" #"application/zip"
        $sourceFile = $uploadfile

        #$fileName = "$( $uploadname )/$( [System.IO.Path]::GetFileName($sourceFile) )"
        $filename = $uploadfolder + $uploadfilename
        $contentHash = (( Get-FileHash $sourceFile -Algorithm SHA256 ).Hash ).ToLower()

        break

    }

     "CREATEFOLDER" {

        $verb = "PUT"
        $bucket = "apteco.campaign-automation.de"        
        
        $contentType = "text/plain" #"application/zip"

        $filename = $uploadfolder

        break

    }

}


<#########################

FUNCTIONS

#########################>

function getSHA256($data) {
    
    $hash = [System.Security.Cryptography.SHA256]::Create()
    $array = $hash.ComputeHash( [System.Text.Encoding]::UTF8.GetBytes($data) )
    return $array

}

# inspired by https://gallery.technet.microsoft.com/scriptcenter/Get-StringHash-aa843f71
function HmacSHA256($data, $key) {
    
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256    
    $hmacsha.key = $key    
    $sign = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($data))
    return $sign

}

function getStringFromByte($byteArray) {

    $stringBuilder = ""
    $byteArray | ForEach { $stringBuilder += $_.ToString("x2") }
    return $stringBuilder

}

function getSignatureKey([String] $key, [String] $dateStamp, [String] $regionName, [String] $serviceName) {
    
    $kSecret = [Text.Encoding]::UTF8.GetBytes("AWS4$($key)")
    $kDate = HmacSHA256 -data $dateStamp -key $kSecret    
    $kRegion = HmacSHA256 -data $regionName -key $kDate
    $kService = HmacSHA256 -data $serviceName -key $kRegion
    $kSigning = HmacSHA256 -data "aws4_request" -key $kService

    return $kSigning # return of signing key as byte array

}




<#########################

PREPARATION

#########################>

$currentDate = Get-Date
$date = $currentDate.ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$dateStamp = $currentDate.ToUniversalTime().ToString("yyyyMMdd")

$scope = "$( $dateStamp )/$( $region )/$( $service )/aws4_request"

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols

#[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$false}


# add bucket and dot if it is used
[System.Uri]$endpoint = "$( $endpoint.AbsoluteUri )$( $bucket )$( if ($bucket -ne '') { '/' } )$( $fileName )" # $( $bucket )$( if ($bucket -ne '') { '.' } )


<#########################

CREATE THE CANONICAL REQUEST

#########################>

$canonicalRequestPlain = "$( $verb )`n$( $endpoint.AbsolutePath )`n`ncontent-type:$( $contentType )`nhost:$( $endpoint.Host )`nx-amz-content-sha256:$( $contentHash )`nx-amz-date:$( $date )`n`ncontent-type;host;x-amz-content-sha256;x-amz-date`n$( $contentHash )"
$canonicalRequestByte = getSHA256 -data $canonicalRequestPlain
$canonicalRequestHash = getStringFromByte -byteArray $canonicalRequestByte


<#########################

CREATE THE STRING TO SIGN

#########################>

$stringToSign = "AWS4-HMAC-SHA256`n$( $date )`n$( $scope )`n$( $canonicalRequestHash )"


<#########################

CREATE THE SIGNATURE KEY

#########################>

$sign = getSignatureKey -key $secretKey -dateStamp $dateStamp -regionName $region -serviceName $service


<#########################

CREATE THE SIGNATURE
Combines "String to sign" with the "Signature Key"

#########################>

$signatureByte = HmacSHA256 -data $stringToSign -key $sign
$signatureHash = getStringFromByte -byteArray $signatureByte


<#########################

GENERATE THE CALL

#########################>

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Host", $endpoint.Host)
$headers.Add("Content-Type", $contentType)
$headers.Add("x-amz-content-sha256", $contentHash)
$headers.Add("x-amz-date", $date)
$headers.Add("Authorization", "AWS4-HMAC-SHA256 Credential=$($accessKey)/$($scope),SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date,Signature=$( $signatureHash )")


switch ($operation) {
   
    "DOWNLOADFILE" {

        # 20 seconds for 20MB with invoke-restmethod
        #$result = Invoke-RestMethod -uri $endpoint -Method $verb -Headers $headers -Verbose
        
        # Done in 20 seconds too, but this method should run faster in parallel for bigger sizes
        $ProgressPreference = 'SilentlyContinue'
        Measure-Command {
            $wc = New-Object System.Net.WebClient
            $headers.Keys | ForEach { $wc.Headers.Add($_, $headers.Item($_)) }
            $wc.DownloadFile($endpoint, $targetFile)
        } | select TotalSeconds

        break

    }
    
    "UPLOADFILE" {
        
        $ProgressPreference = 'SilentlyContinue'
        Measure-Command {
            Invoke-RestMethod -uri $endpoint -Method $verb -Headers $headers -InFile $sourceFile
        } | select TotalSeconds
        
        #$ProgressPreference = 'SilentlyContinue'
        #$result = Invoke-RestMethod -uri $endpoint -Method $verb -Headers $headers -Verbose -InFile $sourceFile
        <#
        $wc = New-Object System.Net.WebClient
        #$wc.AllowWriteStreamBuffering = $true
        $headers.Keys | ForEach { $wc.Headers.Add($_, $headers.Item($_)) }
        $wc.UploadFile($endpoint, $verb, $sourceFile)
        #>

        break

    }

    "CREATEFOLDER" {
        
        $ProgressPreference = 'SilentlyContinue'
        Measure-Command {
            Invoke-RestMethod -uri $endpoint -Method $verb -Headers $headers 
        } | select TotalSeconds
        

        break

    }

    default {

        $result = Invoke-RestMethod -uri $endpoint -Method $verb -Headers $headers -Verbose    
        break

    }

}

