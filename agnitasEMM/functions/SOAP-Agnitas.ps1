
Function Format-SoapParameter {

    param(
         [Parameter(Mandatory=$true)]$key
        ,[Parameter(Mandatory=$true)]$var
        ,[Parameter(Mandatory=$false)][array]$customFields = @()
    )

    # if the datatype is set manually
    if ( $var -is "System.Collections.Hashtable") {
        $noDimensions = Count-Dimensions -var $var.value
        $datatype = $var.type
        $value = $var.value
    } else {
        $noDimensions = Count-Dimensions -var $var
        $value = $var
    }

    
    $xml = Switch ( $noDimensions ) {
        
        # one-dimensional like a integer, string, decimal, long, ...
        0 {
            
            

            # is pscustomobject
            if ($value -is [System.Management.Automation.PSCustomObject]) {
            
                $xmlRaw = ""

                $xmlRaw += "<$( $key ) SOAP-ENC:arrayType=""xsd:$( $datatype )"" xsi:type=""$( $key )"">"
                $value.psobject.properties.name | ForEach {        
                    $property = $_
                    $xmlRaw += "`n        <$( $property ) xsd:type=""xsd:$( $value.$property.type )"">$( [System.Security.SecurityElement]::Escape($value.$property.value) )</$( $property )>"
                }    
                $xmlRaw += "</$( $key )>"

                

            # is array
            } elseif (Is-Numeric $var) {            
                # TODO [ ] this does not work right for decimals, but they are not needed at the moment because the SOAP only uses strings and longs            
                $datatype = "long"
                $xmlRaw = "<$( $key ) xsi:type=""xsd:$( $datatype )"">$( [System.Security.SecurityElement]::Escape( $value ) )</$( $key )>"
            }  else {
                $datatype = "string"
                $xmlRaw = "<$( $key ) xsi:type=""xsd:$( $datatype )"">$( [System.Security.SecurityElement]::Escape( $value ) )</$( $key )>"
            }
            
            $xmlRaw  



        }

        # two- or multidimensional like an text-array of pscustomobject-array
        default {
            
            if ( $value -is [array] ) {
                
                # array of pscustomobjects
                if ($value[0] -is [System.Management.Automation.PSCustomObject]) {
                
                    if ($value -is [array] -and $value[0] -is [System.Management.Automation.PSCustomObject]) {
            
            
                        $xmlRaw = ""

                        $xmlRaw += "<$( $key ) SOAP-ENC:arrayType=""xsd:$( $datatype )[$( $value.Count )]"" xsi:type=""$( $key )"">"

                        # Go for each row (each recipient)
                        $value  | ForEach {    
                            $item = $_
                            $xmlRaw += "`n    <item xsi:type=""SOAP-ENC:$( $datatype )"">"    

                            # Go for each property/value of recipient and exclude custom fields
                            $item.psobject.properties.name.Where( { $_ -notin $customFields.id } ) | ForEach {  
                                
                                $property = $_
                                
                                if ( $property -eq "custom" ) {
                                    
                                    # evaluate number of filled custom fields
                                    $customFieldNames = $item.psobject.Properties | where { $_.value -ne $null -and $_.name -in $customFields.id }

                                    $item | select $customFieldNames.name | ForEach {
    
                                        $row = $_
                                        $i = 0
                                        $xmlCustom = ""
                                        $row.psobject.properties.name | ForEach {
    
                                            $attribute = $_
        
                                            if ( $row.$attribute -ne $null) {
                                                $i+=1
                                                $xmlCustom += "<item xsi:type=""xsd:CustomFieldType"" id=""ref$( $i )"">" # TODO add number
                                                $xmlCustom += "  <variableName xsi:type=""xsd:string"">$( $attribute )</variableName>"
                                                $xmlCustom += "  <value xsi:type=""xsd:$( $customFields.Where({ $_.id -eq $attribute }).type )"">$( [System.Security.SecurityElement]::Escape( $row.$attribute ) )</value>"
                                                $xmlCustom += "</item>"
                                                $itemValue = $xmlCustom
                                            }

                                        }

                                    }
                                    $propertyDataType = "customFieldTypeItems"
                                    $arrayType = "SOAP-ENC:arrayType=""xsd:customFieldType[$( $customFieldNames.Count )]"""
                                    $xsiOrXsd = "xsi"

                                } else {
                                    $arrayType = ""
                                    $propertyDataType = "string"
                                    $itemValue = $item.$property
                                    $xsiOrXsd = "xsd"
                                }
                                  
                                #<custom SOAP-ENC:arrayType="ns1:CustomFieldType[32]" xsi:type="ns1:customFieldTypeItems">

                                $xmlRaw += "`n        <$( $property ) $( $arrayType ) $( $xsiOrXsd ):type=""xsd:$( $propertyDataType )"">$( [System.Security.SecurityElement]::Escape($itemValue) )</$( $property )>"
                            }    
                            $xmlRaw += "`n    </item>"        
                        }
                        $xmlRaw += "</$( $key )>"

                        $xmlRaw


                    }


                # array of strings other than pscustomobjects
                } else {

@"
<$( $key ) SOAP-ENC:arrayType="xsd:string[$( $value.Count )]" xsi:type="ArrayOf_xsd_string">$( $value | ForEach {                
    "`n    <item xsd:type=""xsd:string"">$( [System.Security.SecurityElement]::Escape( $_ ) )</item>"                
})
</$( $key )>
"@
                
                }
            }
           
            
        }
        <#
        2 {
    
@"
<$( $key ) SOAP-ENC:arrayType="xsd:string[][$( $var.Count )]" xsi:type="ArrayOfArrayOf_xsd_string">$($var | ForEach {
    "`n    <item SOAP-ENC:arrayType=""xsd:string[$( $_.Count )]"" xsi:type=""SOAP-ENC:Array"">$( $_ | ForEach {
        "`n        <item xsd:type=""""xsd:string"""">$( $_ )</item>"
    } )`n    </item>"
} )
</$( $key )>
"@

        }
        #>
    }

    return $xml

}



Function Invoke-Agnitas {

    param(
         [Parameter(Mandatory=$true)][String]$method
        #,[Parameter(Mandatory=$true)][Hashtable]$wsse
        ,[Parameter(Mandatory=$false)][Hashtable]$param = @{}
        ,[Parameter(Mandatory=$false)][String]$responseNode = "" # you should either define responseNode or responseType
        ,[Parameter(Mandatory=$false)][String]$responseType = "" # you should either define responseNode or responseType
        ,[Parameter(Mandatory=$false)][switch]$verboseCall = $false
        ,[Parameter(Mandatory=$false)][array]$customFields = @()
        ,[Parameter(Mandatory=$false)][switch]$returnFlat = $false
    )

    # load url and header
    $baseUri = $settings.base
    $wsse = Create-WSSE-Token -cred $script:cred -noMilliseconds

    <#
    $headers = @{
        userId=$settings.login.user     # Integer, The user id, from the account you wish to access.
        userToken=Get-SecureToPlaintext $settings.login.token # String, your personal token
    }
    #>

    try {
            
        # format SOAP parameters        
        <#
        $paramXML = ""
        $param.Keys | ForEach {
            $key = $_
            $paramXML += Format-SoapParameter -key $key -var $param[$key] -customFields $customFields
        }
        #>

    $nonceBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($wsse.nonce))

        # create SOAP envelope
        $soapEnvelopeXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://agnitas.org/ws/schemas">
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
        <ns1:$( $method )Request/>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
"@        
# <?xml version="1.0" encoding="UTF-8"?>
# <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
#     <SOAP-ENV:Header>
#         $( $wsseHeader )
#     </SOAP-ENV:Header>
#     <SOAP-ENV:Body xmlns:ns2="http://agnitas.org/ws/schemas" xmlns:ns3="http://agnitas.com/ws/schemas">
#     <ns2:$( $method )Request>

#     </ns2:$( $method )Request>
#     </SOAP-ENV:Body>
# </SOAP-ENV:Envelope>
# "@

        if ( $verboseCall ) {
            Write-Host $soapEnvelopeXml
        }

        $headers = @{
            "SOAPACTION" = "" #$method
        }

        #$soapEnvelopeXml | Out-File -FilePath "$( $Path )\..\log\env_out.xml"

        $contentType = "text/xml; charset=utf-8" #"text/xml;charset=""utf-8"""
        $res = Invoke-RestMethod -Uri "$( $baseUri )" -Headers $headers -ContentType $contentType -Method Post -Body $soapEnvelopeXml -Verbose #-SkipHeaderValidation #-OutFile "$( ([guid]::NewGuid()).Guid ).xml"
        $response = $res #[xml]$res.Content
        #write-host "Statuscode '$( $res.StatusCode )' with Statusdescription '$( $res.StatusDescription )'"

    } catch {
        Write-Host $_.Exception
        Write-Host $_.Exception.Response.StatusCode.value__
        Write-Host $_.Exception.Response.StatusDescription.value__
        #If ($_.Exception.Response.StatusCode.value__ -eq "500") {
        #}
    }

   
    # print response to console
    if ( $verboseCall ) {
        write-host $response.OuterXml
        Out-File -InputObject $response.OuterXml -Encoding utf8 -FilePath ".\$( ([guid]::NewGuid()).guid ).xml"
    }

    # load namespaces of response
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

    # load item of xml containing "item"
 
    $responseParsed = $response | Select-Xml -XPath "//SOAP-ENV:Body" -Namespace $ns | select -ExpandProperty node | Convert-XMLtoPSObject -ignoreNamespaces $ns

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
   $responseParsed."$( $method )Response"

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