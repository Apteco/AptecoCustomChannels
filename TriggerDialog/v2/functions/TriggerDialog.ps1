# This function fills the variable $Script:sessionId with the current session id
Function Get-TriggerDialogSession {

    $sessionPath = "$( $settings.sessionFile )"

    # if file exists -> read it and check ttl
    $createNewSession = $true
    if ( (Test-Path -Path $sessionPath) -eq $true ) {

        $sessionContent = Get-Content -Encoding UTF8 -Path $sessionPath -Raw | ConvertFrom-Json
        
        $expire = [datetime]::ParseExact($sessionContent.expire,"yyyyMMddHHmmss",[CultureInfo]::InvariantCulture)

        if ( $expire -gt [datetime]::Now ) {

            $createNewSession = $false
            $Script:sessionId = $sessionContent.sessionId
            
        }

    }
    
    # file does not exist or date is not valid -> create session
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
    
    }

}

Function Get-LoginViaCredentials {

    $body = @{
        "partnerSystemIdExt" = $settings.authentication.partnerSystemIdExt
        "partnerSystemCustomerIdExt"= $settings.authentication.partnerSystemCustomerIdExt
        "authenticationSecret"= Get-SecureToPlaintext -String $settings.authentication.authenticationSecret
        "locale"= "de"
    }    
    $bodyJson = $body | ConvertTo-Json
    
    $cred = Invoke-RestMethod -Method Post -Uri "$( $settings.base )/authentication/partnersystem/credentialsbased" -Headers @{ "accept" = $settings.contentType } -ContentType $settings.contentType -Body $bodyJson -Verbose 
    return $cred.jwtToken
    
    #$jwtDecoded = Decode-JWT -token $cred.jwtToken -secret $settings.authentication.authenticationSecret

}

Function Get-LoginViaToken {

    $body = @{
        "jwtToken" = $jwt
    }
    $bodyJson = $body | ConvertTo-Json
    
    $cred = Invoke-RestMethod -Method Post -Uri "$( $settings.base )/authentication/partnersystem/tokenbased" -Headers @{"accept" = $settings.contentType} -ContentType $settings.contentType -Body $bodyJson -Verbose
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

        $postcodeSynonyms = @("Postleitzahl","zip","zip code","zip-code","PLZ")
        $countrycodeSynonyms = @("iso","country","land","länderkennzeichen")

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
            # TODO [ ] put this list into the settings
            $postcodeSynonyms | ForEach {
                if ( $fieldname -like "*$( $_ )*" ) {
                    $dataTypeCheck["80"] = $true
                }
            } 

            # Check data type - countrycode
            # TODO [ ] put this list into the settings
            $countrycodeSynonyms | ForEach {
                if ( $fieldname -like "*$( $_ )*" ) {
                    $dataTypeCheck["90"] = $true
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
