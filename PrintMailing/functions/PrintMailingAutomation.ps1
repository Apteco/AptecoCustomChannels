

################################################
#
# GENERIC CLASSES AND ENUMS
#
################################################

# TODO [ ] implement using these enums

enum TriggerDialogCampaignState {
    Entwurf = 110          # Entwurf
    Aktiv = 120           # Aktiv
    Pausiert = 125          # Pausiert/Paused
}

enum TriggerDialogTemplateType {
    Basic = 110     # "Basic" in UI
    Plus = 120      # Also entitled as Basic, but in UI as "Plus"
    Advanced = 230  # "Unique in UI" 
}

enum TriggerDialogDataTypes {
    String = 10    # String, is always an option
    Int = 20
    Bool = 30
    Date = 40
    Image = 50
    ImageUrl = 60
    Float = 70
    Postcode = 80
    CountryCode = 90
}


################################################
#
# FUNCTIONS
#
################################################


# This function fills the variable $Script:sessionId with the current session id and the default parameters
Function Get-TriggerDialogSession {
    [CmdletBinding()]
    param ()
    
    begin {

        $sessionPath = "$( $settings.sessionFile )"
        $return = $false

    }
    
    process {
        

        #-----------------------------------------------
        # IF FILE EXISTS -> READ IT AND CHECK TTL
        #-----------------------------------------------

        $createNewSession = $true
        if ( (Test-Path -Path $sessionPath) -eq $true ) {

            $sessionContent = Get-Content -Encoding UTF8 -Path $sessionPath -Raw | ConvertFrom-Json
            
            $expire = [datetime]::ParseExact($sessionContent.expire,"yyyyMMddHHmmss",[CultureInfo]::InvariantCulture)

            if ( $expire -gt [datetime]::Now -or $sessionContent.sessionId -eq "null") {

                $createNewSession = $false
                $Script:sessionId = $sessionContent.sessionId
                
            }

        }

        
        #-----------------------------------------------
        # FILE DOES NOT EXIST OR DATE IS NOT VALID -> CREATE SESSION
        #-----------------------------------------------

        if ( $createNewSession -eq $true ) {
            
            $expire = [datetime]::now.AddMinutes( $settings.ttl ).ToString("yyyyMMddHHmmss")

            #$pass = Get-SecureToPlaintext $settings.login.pass
            #$login = Get-LoginViaCredentials
            $sessionId = Get-LoginViaCredentials
            
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
            
            $return = $true
        }

    }
    
    end {
        # return $true, if a new session was created
        $return
    }




}

Function Get-LoginViaCredentials {

    $body = @{
        "partnerSystemIdExt" = $settings.authentication.partnerSystemIdExt
        "partnerSystemCustomerIdExt"= $settings.authentication.partnerSystemCustomerIdExt
        "authenticationSecret"= Get-SecureToPlaintext -String $settings.authentication.authenticationSecret
        "locale"= "de"
    }
    $bodyJson = ConvertTo-Json -InputObject $body -Depth 99
    
    $params = [hashtable]@{
        Uri = "$( $settings.base )/user/authentication/partnersystem/credentialsbased"
        Headers = @{
            "accept" = $settings.contentType
        }
        ContentType = $settings.contentType
        Verbose = $true
        Method = "Post"
        Body = $bodyJson
    }

    $cred = Invoke-RestMethod @params
    return $cred.jwtToken
    
    #$jwtDecoded = Decode-JWT -token $cred.jwtToken -secret $settings.authentication.authenticationSecret

}

Function Get-LoginViaToken {

    $body = @{
        "jwtToken" = $jwt
    }
    $bodyJson = $body | ConvertTo-Json -Depth 99
    
    $params = [hashtable]@{
        Uri = "$( $settings.base )/user/authentication/partnersystem/tokenbased"
        Headers = @{
            "accept" = $settings.contentType
        }
        ContentType = $settings.contentType
        Body = $bodyJson
        Verbose = $true
        Method = "Post"
    }

    $cred = Invoke-RestMethod @params
    return $cred.jwtToken
    
}

Function Get-LoginViaPostShop {

    # TODO [ ] Not sure about this one?

    #Invoke-RestMethod -Method Post -Uri "$( $settings.base )/authentication/postshoplogin" -Verbose -Headers @{"accept" = "application/json"} -ContentType "application/json" -Body $bodyJson

}

Function Create-JwtToken {

    param(        
         [Parameter(Mandatory=$true)][PSCustomObject]$headers
        ,[Parameter(Mandatory=$true)][PSCustomObject]$payload
        ,[Parameter(Mandatory=$true)][string]$secret
    )

    #-----------------------------------------------
    # CREATE PAYLOAD
    #-----------------------------------------------

    $timestamp = Get-Unixtime -timestamp ( [datetime]::Now )

    $payloadCopy = $payload.PsObject.Copy()
    $payloadCopy.iat = $timestamp
    $payloadCopy.exp = ( $timestamp + 120 )              # Default JWT expiry to 120 seconds

    #-----------------------------------------------
    # CREATE JWT AND AUTH URI
    #-----------------------------------------------

    $jwt = Encode-JWT -headers $headers -payload $payloadCopy -secret $secret
    return $jwt

}

Function Create-VariableDefinitions {

    param(        
         [Parameter(Mandatory=$true)][PSCustomObject]$personalisation
    )

    begin {


    }
    
    process {
        
        # Go through all fields - the inital personalisation fields do not contain test data
        # so only the names of the fields will be checked
        $sortOrder = 10
        $variableDefinitions = @()
        $personalisation | Get-Member -Type NoteProperty | ForEach {

            $fieldname = $_.Name
            $value = $personalisation.$fieldname

            <#
            dataTypeIds can be found in the lookups
            id label
            -- -----
            10 Text
            20 Ganzzahl
            30 Boolscher Wert
            40 Datum
            50 Bild
            60 Bild-URL
            70 Fließkommazahl
            80 Postleitzahl
            90 Ländercode
            
            required fields are zip and city

            #>

            # Create an object with all datatypes
            $dataTypeCheck = [Ordered]@{
                "10" = $true    # String, is always an option
                "20" = $false   # Int
                "30" = $false   # Bool
                "40" = $false   # Date
                "50" = $false   # Image
                "60" = $false   # Image Url
                "70" = $false   # Float/Double
                "80" = $false   # Postcode
                "90" = $false   # CountryCode
            }

            # TODO [ ] Implement check for Date -> see triggerdialog documentation
            # TODO [ ] Implement check for Image -> Not supported at the moment
            # TODO [ ] Implement check for Bool

            # CHECKS FOR VARIABLE NAMES

            # Check data type - postcode
            # TODO [x] put this list into the settings
            $settings.dataTypes.postcodeSynonyms | ForEach {
                if ( $fieldname -like "*$( $_ )*" ) {
                    $dataTypeCheck["80"] = $true
                }
            } 

            # Check data type - countrycode
            # TODO [x] put this list into the settings
            $settings.dataTypes.countrycodeSynonyms | ForEach {
                if ( $fieldname -like "*$( $_ )*" ) {
                    $dataTypeCheck["90"] = $true
                }
            } 

            $settings.dataTypes.picturesEmbeddedSynonyms | ForEach {
                if ( $fieldname -like "*$( $_ )*" ) {
                    $dataTypeCheck["50"] = $true
                }
            } 

            $settings.dataTypes.picturesLinkSynonyms | ForEach {
                if ( $fieldname -like "*$( $_ )*" ) {
                    $dataTypeCheck["60"] = $true
                }
            } 

            # CHECKS FOR VARIABLE VALUES

            # Check data type - image link via regex
            if ( Is-Link $value ) {
                $dataTypeCheck["60"] = $true
            }

            # Check data type - Ganzzahl
            if ( Is-Int $value ) {
                $dataTypeCheck["20"] = $true
            }

            # Check data type - Float, needs a point as decimal
            if ( Is-Float $value ) {
                $dataTypeCheck["80"] = $true
            }

            # DECISION FOR THE DATATYPE

            # Get the datatypes with true value and the max name/key
            $dataType = ( $dataTypeCheck.GetEnumerator() | where { $_.Value -eq $true } | select -last 1 ).Name
            
            # Create the object for the definitions
            $variableDefinitions += [PSCustomObject]@{
                "label" = $fieldname
                "sortOrder" = $sortOrder
                "dataTypeId" = $dataType
                #"x" = 0
                #"y" = 0
                #"font" = 0
                #"fontSize" = 0
                #"spanHeight" = 0
            }

            # Add 10 to the sortorder
            $sortOrder += 10

        }

    }

    end {
        
        # TODO [x] check that we only have ONE zipcode field, not more and not less
        $postcodeVariables = @( $variableDefinitions | where { $_.dataTypeId -eq 80 } )
        if ( $postcodeVariables.Count -ne 1 ) {

            # Write log
            Write-Log "You have $( $postcodeVariables.Count ) postcode variables. Please make sure you have one."

            # Throw Exception
            throw [System.IO.InvalidDataException] "You have $( $postcodeVariables.Count ) postcode variables. Please make sure you have one."  
            
        }

        # return object
        $variableDefinitions

    }

}


Function Invoke-TriggerDialog {

    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$true)][String] $customerId
        ,[Parameter(Mandatory=$true)][String] $path
        ,[Parameter(Mandatory=$false)][String] $contentType = "application/json; charset=utf-8"
        ,[Parameter(Mandatory=$false)][Microsoft.PowerShell.Commands.WebRequestMethod] $method = "Get"
        ,[Parameter(Mandatory=$false)][Hashtable] $headers = @{}
        ,[Parameter(Mandatory=$false)][Hashtable] $body = @{}
        ,[Parameter(Mandatory=$false)][String] $rawBody = ""
        ,[Parameter(Mandatory=$false)][Hashtable] $additionalQuery = @{}
        #,[Parameter(Mandatory=$false)][System.Collections.ArrayList] $parameters = $null
        ,[Parameter(Mandatory=$false)][int] $pagingSize = 2 # TODO [ ] change this to a max of 2k
        ,[Parameter(Mandatory=$false)][switch] $deactivatePaging = $false
        ,[Parameter(Mandatory=$false)][switch] $returnRawObject = $false
    )
    
    begin {

        #-----------------------------------------------
        # CHECK THE VALID SESSION OR CREATE A NEW ONE
        #-----------------------------------------------
<#
        #$headers = @{}
        $newSessionCreated = Get-TriggerDialogSession
        if ( $newSessionCreated ) {
            # Choose if we replace or add the auth
            if ( $headers.Authorization ) {
                $headers.Authorization = "Bearer $( Get-SecureToPlaintext -String $Script:sessionId )"
            } else {
                $headers.add("Authorization", "Bearer $( Get-SecureToPlaintext -String $Script:sessionId )")
            }
        }
#>
        #-----------------------------------------------
        # HEADER + CONTENTTYPE + BASICS
        #-----------------------------------------------

        $uri = "$( $settings.base )/automation"

        $defaultParams = @{
            Headers = $headers
            Verbose = $true
            ContentType = $contentType
        }

        <#
        if ( $parameters -ne $null ) {
            $param = "json=$( Format-ELAINE-Parameter $parameters )"
        } else {
            $param = ""
        }
        #>

        #-----------------------------------------------
        # CALL PARAMETERS
        #-----------------------------------------------

        Switch ( $method.toString() ) {

            "Get" {
                
                $params = $defaultParams + @{
                    Uri = "$( $uri )/$( $path )?customerId=$( $customerId )"
                    Method = $method.toString()
                }

            }

            "Post" {

                $deactivatePaging = $true
                
                if ( $rawBody -ne "" ) {
                    $bodyJson = $rawBody
                } else {
                    $bodyJson = ConvertTo-Json -InputObject $body -Depth 99
                }

                $params = $defaultParams + @{
                    Uri = "$( $uri )/$( $path )?customerId=$( $customerId )"
                    Method = $method.toString()
                    Body = $bodyJson
                }         

            }

            "Put" {

                $deactivatePaging = $true

                $bodyJson = ConvertTo-Json -InputObject $body -Depth 99

                $params = $defaultParams + @{
                    Uri = "$( $uri )/$( $path )?customerId=$( $customerId )"
                    Method = $method.toString()
                    Body = $bodyJson
                }

            }

            "Delete" {

                $deactivatePaging = $true
                $returnRawObject = $true

                $params = $defaultParams + @{
                    Uri = "$( $uri )/$( $path )?customerId=$( $customerId )"
                    Method = $method.toString()
                }

            }

            Default {
                throw [System.IO.InvalidDataException] "Method not implemented yet"  
            }

        }
        
        foreach($key in $additionalQuery.Keys) {
            $value = $t.$key
            $params.Uri = "$( $params.Uri )&$( $key )=$( $value )"
            #Write-Output "$key : $value"
        }
        


    }
    
    process {
                
        #-----------------------------------------------
        # PAGE THROUGH RESULTS
        #-----------------------------------------------

        $size = $pagingSize
        $page = 0
        <#
        $params = @{
            Method = $method
            Uri = "$( $settings.base )/$( $path )?customerId=$( $customerId )"
            Verbose = $true
            Headers = $headers
            ContentType = $contentType
            # Body = $bodyJson
        }
        #>
        
        # Only if it is a get request, build an array
        if ( -not $returnRawObject ) {
            $totalResult = [System.Collections.ArrayList]@()
        }

        $initUrl = $params.Uri
        Do {
            
            # Setup paging, if not deactivated
            if ( -not $deactivatePaging ) {
                $params.Uri = "$( $initUrl )&size=$( $size )&page=$( $page )" # &sort=id,desc
            }

            # Try the call
            try {
                $pageResult = Invoke-RestMethod @params -TimeoutSec 90
            } catch {
                $errorMessage = ParseErrorForResponseBody -err $_
                $errorMessage.errors | ForEach {
                    Write-Log -severity ( [LogSeverity]::ERROR ) -message "$( $_.errorCode ) : $( $_.errorMessage )"
                }
                Throw [System.IO.InvalidDataException]
            }

            # Add the results to array or give the plain response back
            if ( $returnRawObject ) {
                $totalResult = $pageResult
            } else {
                $totalResult.AddRange( $pageResult.elements )
            }
            
            # Increase the page
            $page += 1
        
        # Check if we are on the last page
        } while ( ($pageResult.page.number + 1) -lt $pageResult.page.totalPages )        

    }
    
    end {
        
        # return
        $totalResult

    }

}
