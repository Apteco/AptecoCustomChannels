
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
                    $xmlRaw += "`n        <$( $property ) xsd:type=""xsd:$( $value.$property.type )"">$( $value.$property.value )</$( $property )>"
                }    
                $xmlRaw += "</$( $key )>"

                

            # is array
            } elseif (Is-Numeric $var) {            
                # TODO [ ] this does not work right for decimals, but they are not needed at the moment because the SOAP only uses strings and longs            
                $datatype = "long"
                $xmlRaw = "<$( $key ) xsi:type=""xsd:$( $datatype )"">$( $value )</$( $key )>"
            }  else {
                $datatype = "string"
                $xmlRaw = "<$( $key ) xsi:type=""xsd:$( $datatype )"">$( $value )</$( $key )>"
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
                                                $xmlCustom += "  <value xsi:type=""xsd:$( $customFields.Where({ $_.id -eq $attribute }).type )"">$( $row.$attribute )</value>"
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

                                $xmlRaw += "`n        <$( $property ) $( $arrayType ) $( $xsiOrXsd ):type=""xsd:$( $propertyDataType )"">$( $itemValue )</$( $property )>"
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
    "`n    <item xsd:type=""xsd:string"">$( $_ )</item>"                
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


Function Invoke-Flexmail {

    param(
         [Parameter(Mandatory=$true)][String]$method
        ,[Parameter(Mandatory=$false)][Hashtable]$param = @{}
        ,[Parameter(Mandatory=$false)][String]$responseNode = ""
        ,[Parameter(Mandatory=$false)][switch]$verboseCall = $false
        ,[Parameter(Mandatory=$false)][array]$customFields = @()
    )

    # load url and header
    $baseUri = $settings.base
    $headers = @{
        userId=$settings.login.user     # Integer, The user id, from the account you wish to access.
        userToken=Get-SecureToPlaintext $settings.login.token # String, your personal token
    }


    try {
            
        # format SOAP parameters        
        $paramXML = ""
        $param.Keys | ForEach {
            $key = $_
            $paramXML += Format-SoapParameter -key $key -var $param[$key] -customFields $customFields
        }        

        # create SOAP envelope
        $soapEnvelopeXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:ns1="https://soap.flexmail.eu/3.0.0/flexmail.wsdl" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <SOAP-ENV:Body>
        <SOAP-ENV:$( $method )>
            <$( $method )Req xsi:type="ns1:$( $method )Req">
                <header xsi:type="ns1:APIRequestHeader">
                    <userId xsi:type="xsd:int">$( $headers.userId )</userId>
                    <userToken xsi:type="xsd:string">$( $headers.userToken )</userToken>
                </header>
                $( $paramXml )
            </$( $method )Req>
        </SOAP-ENV:$( $method )>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
"@
        if ( $verboseCall ) {
            Write-Host $soapEnvelopeXml
        }

        #$headers += @{
        #    "SOAPACTION" = $method
        #}

        $contentType = "text/xml;charset=""utf-8"""
        $res = Invoke-RestMethod -Uri "$( $baseUri )" -ContentType $contentType -Method Post -Body $soapEnvelopeXml -Verbose #-OutFile "$( ([guid]::NewGuid()).Guid ).xml"
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
    }

    # load item of xml containing "item"
    if ( $responseNode -eq "" ) {
        $responseItems = $response.Envelope.Body."$( $method )Response"."$( $method )Resp".SelectNodes("//*[contains(local-name(),'Items')]")
    } else {
        $responseItems = $response.Envelope.Body."$( $method )Response"."$( $method )Resp"."$( $responseNode )"
    }

    # load xml result into array
    $items = @()
    if ( $responseItems.ChildNodes -ne $null ) {
        $responseItems.ChildNodes | ForEach {

            $inputItem = $_
            $item = New-Object PSCustomObject
            $inputItem.ChildNodes.Name | ForEach {
                $name = $_       
                $item | Add-Member -MemberType NoteProperty -Name $name -Value $inputItem."$( $name )".'#text'
            }
            $items += $item
            #$id = $t.item.categoryId.'#text'

        }
    }

    # return the results
    return $items

}