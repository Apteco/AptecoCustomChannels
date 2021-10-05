
Function Format-SoapParameter {

    param(
         [Parameter(Mandatory=$true)][String]$key
        ,[Parameter(Mandatory=$true)][Hashtable]$var
        #,[Parameter(Mandatory=$false)][array]$customFields = @()
    )
    
    # if the datatype is set manually
    #if ( $var -is "System.Collections.Hashtable") {
        #$noDimensions = Count-Dimensions -var $var.value
        $datatype = $var.type
        $value = $var.value
    #} else {
        #$noDimensions = Count-Dimensions -var $var
#        $value = $var
#    }

    #$xmlRaw = "<ns1:$( $key ) xsi:type=""xsd:$( $datatype )"">$( [System.Security.SecurityElement]::Escape( $value ) )</ns1:$( $key )>"

    $xmlRaw = @"
            <ns1:$( $key )>$( [System.Security.SecurityElement]::Escape( $value ) )</ns1:$( $key )>
"@

    #$xml = @"
    #<ns1:$( $key )>$( $var )</ns1:$( $key )>
#
#"@
    return $xmlRaw

}



Function Invoke-Agnitas {

    param(
         [Parameter(Mandatory=$true)][String]$method
        #,[Parameter(Mandatory=$true)][Hashtable]$wsse
        ,[Parameter(Mandatory=$false)][Hashtable]$param = @{}
        #,[Parameter(Mandatory=$false)][String]$responseNode = "" # you should either define responseNode or responseType
        #,[Parameter(Mandatory=$false)][String]$responseType = "" # you should either define responseNode or responseType
        ,[Parameter(Mandatory=$false)][switch]$verboseCall = $false
        #,[Parameter(Mandatory=$false)][array]$customFields = @()
        #,[Parameter(Mandatory=$false)][switch]$returnFlat = $false
        ,[Parameter(Mandatory=$false)][String]$namespace = "http://agnitas.org/ws/schemas"
        ,[Parameter(Mandatory=$false)][switch]$noResponse = $false
        )

    # load url
    $baseUri = $settings.base

    # authentication
    $wsse = Create-WSSE-Token -cred $script:cred -noMilliseconds
    $nonceBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($wsse.nonce))
    

    try {
            
        # format SOAP parameters        
        
        $paramXML = ""
        $param.Keys | ForEach {
            $key = $_
            $paramXML += Format-SoapParameter -key $key -var $param[$key] #-customFields $customFields
        }

        # create headers
        $contentType = "text/xml; charset=utf-8" #"text/xml;charset=""utf-8"""
        $headers = @{
            "SOAPACTION" = "" #$method
        }

        # create SOAP envelope
        $soapEnvelopeXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="$( $namespace )">
    <SOAP-ENV:Header>
        <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
            <wsse:UsernameToken xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
                <wsse:Username>$( $wsse.Username )</wsse:Username>
                <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">$( $wsse.PasswordDigest )</wsse:Password>
                <wsse:Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">$( $nonceBase64 )</wsse:Nonce>
                <wsu:Created xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">$( $wsse.Created )</wsu:Created>
            </wsse:UsernameToken>
        </wsse:Security>
    </SOAP-ENV:Header>
    <SOAP-ENV:Body>
        <ns1:$( $method )Request>
$( $paramXml )
        </ns1:$( $method )Request>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
"@        

        # Write out and log the request
        if ( $verboseCall ) {
            Write-Host $soapEnvelopeXml
            Out-File -InputObject $soapEnvelopeXml -Encoding utf8 -FilePath ".\envelope_$( ([guid]::NewGuid()).guid ).xml"
        }

        # Do the soap call
        $restParams = [Hashtable]@{
            Uri = $baseUri
            Headers = $headers
            ContentType = $contentType
            Method = "Post"
            Body = $soapEnvelopeXml
            Verbose = $true
            #SkipHeaderValidation = $true
            #OutFile = "$( ([guid]::NewGuid()).Guid ).xml"
        }
        $response = Invoke-RestMethod @restParams
        #$response = Invoke-RestMethod -Uri $baseUri -Headers $headers -ContentType $contentType -Method Post -Body $soapEnvelopeXml -Verbose #-SkipHeaderValidation #-OutFile "$( ([guid]::NewGuid()).Guid ).xml"

    } catch {
        Write-Host $_.Exception
        Write-Host $_.Exception.Response.StatusCode.value__
        Write-Host $_.Exception.Response.StatusDescription.value__
        #write-host "Statuscode '$( $res.StatusCode )' with Statusdescription '$( $res.StatusDescription )'"
        #If ($_.Exception.Response.StatusCode.value__ -eq "500") {
        #}
    }

    if (-not $noResponse ) {

        # print response to console and to file
        if ( $verboseCall ) {
            write-host $response.OuterXml
            Out-File -InputObject $response.OuterXml -Encoding utf8 -FilePath ".\response_$( ([guid]::NewGuid()).guid ).xml"
        }

        # load namespaces of response envelope and body
        $namespacePrefix = "xmlns:"
        $ns = [HashTable]@{}
        $response.Envelope.Attributes.name.where({ $_ -like "$( $namespacePrefix )*" }) | ForEach {
            $attributeName = $_
            $namespaceName = $attributeName.Substring($namespacePrefix.Length)
            $nameSpaceUrl = $response.Envelope.Attributes[$attributeName].'#text'
            $ns.Add($namespaceName,$nameSpaceUrl)
        }
        $response.Envelope.Body."$( $method )Response".Attributes.name.where({ $_ -like "$( $namespacePrefix )*" }) | ForEach {
            $attributeName = $_
            $namespaceName = $attributeName.Substring($namespacePrefix.Length)
            $nameSpaceUrl = $response.Envelope.Body."$( $method )Response".Attributes[$attributeName].'#text'
            $ns.Add($namespaceName,$nameSpaceUrl)
        }

        # load body as custom object
        $responseParsed = $response | Select-Xml -XPath "//SOAP-ENV:Body" -Namespace $ns | select -ExpandProperty node | Convert-XMLtoPSObject -ignoreNamespaces $ns
        $responseParsed."$( $method )Response"

    }

    <#
    if ( $responseNode -eq "" -and $responseType -eq "" ) {
        $responseItems = $response.Envelope.Body."$( $method )Response"."$( $method )Response".SelectNodes("//*[contains(local-name(),'Item')]")
    } elseif ( $responseType -ne "" ) {
        $responseItems = $response | Select-Xml -XPath "//item[@xsi:type='ns1:$( $responseType )']" -Namespace $ns | select -expand node
    } else {
        $responseItems = $response.Envelope.Body."$( $method )Response"."$( $method )Resp"."$( $responseNode )"
    }
    #>

    <#
    if ( $responseType -ne "" -or $returnFlat ) {
       
        return $responseItems

    } else {
        
         # load xml result into array
        $items = @()
        if ( $responseItems.ChildNodes -ne $null ) {

            $responseItems.ChildNodes | ForEach {

                $inputItem = $_
                $item = New-Object PSCustomObject
                if ( $_.ChildNodes.Name -eq "#text" ) { # is it one-dimensional
                    $item | Add-Member -MemberType NoteProperty -Name $inputItem.Name -Value $inputItem.'#text'
                } else { # or two-dimensional with subnodes?
                    $inputItem.ChildNodes.Name | ForEach { 
                        $name = $_       
                        $item | Add-Member -MemberType NoteProperty -Name $name -Value $inputItem."$( $name )".'#text'
                    }
                }
                
                $items += $item
                #$id = $t.item.categoryId.'#text'

            }
            
        }
        # return the results
        return $items
    }
    #>

}


# https://emm.agnitas.de/manual/de/pdf/webservice_pdf_de.pdf;jsessionid=99A8712DD785C43358F67AF992E438BA.node2
# https://www.apteco-faststats.de/agnitas_emm_php/WS_use_example.php
#$wsse = Create-WSSE-Token -cred $cred -noMilliseconds
#$mailings = Invoke-Agnitas -method "ListMailings" -wsse $wsse #-verboseCall
#$mailings.item | Out-GridView

<#
<SOAP-ENV:Envelope 
    xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"> 
  <SOAP-ENV:Header/> 
  <SOAP-ENV:Body> 
    <ns2:GetMailinglistResponse 
      xmlns:ns2="http://agnitas.org/ws/schemas" 
      xmlns:ns3="http://agnitas.com/ws/schemas"> 
      <ns2:id>12345</ns2:id> 
      <ns2:shortname>Mailinglist</ns2:shortname> 
      <ns2:description>Example</ns2:description> 
    </ns2:GetMailinglistResponse> 
  </SOAP-ENV:Body> 
</SOAP-ENV:Envelope>
#>

<#
$emm = New-WebServiceProxy -Uri "https://ws.agnitas.de/2.0/emmservices.wsdl" -Namespace WebService
New-WebServiceProxy
#>