Function Format-ELAINE-Parameter {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]$arr
    )

    begin {
        
    }
    
    process {
        $json = ConvertTo-Json -InputObject $arr -Compress -Depth 99
        $jsonEscaped = [uri]::EscapeDataString($json)
    }
    
    end {
        $jsonEscaped
    }

}

<#
# Some tests
Check-ELAINE-Version -minVersion "6.2.2" -currentVersion "6.13.12"
Check-ELAINE-Version -minVersion "6.2.2" -currentVersion "6.2.2"
Check-ELAINE-Version -minVersion "6.2.2" -currentVersion "6.2.1"
Check-ELAINE-Version -minVersion "6.2.2" -currentVersion "6.1.2"
Check-ELAINE-Version -minVersion "6.2.2" -currentVersion "5.2.2"
Check-ELAINE-Version -minVersion "6.2.2" -currentVersion "5.14.0~78933"
#>
Function Check-ELAINE-Version {

    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$true)][String] $minVersion
        ,[Parameter(Mandatory=$false)][String] $currentVersion = ""
    )

    begin {

        # Check if currentVersion is present as script variable
        if ( $currentVersion -eq "" ) {
            if ( $script:elaineVersion -eq $null ) {
                $msg = "No ELAINE version loaded into cache through environment. Please define in script '`$elaineVersion' or use parameter -currentVersion"
                Write-Log $msg
                throw [System.IO.InvalidDataException] $msg

            } else {
                $currentVersion = $script:elaineVersion
            }
        }

    }
    
    process {

        $minVersionParts = $minVersion.Split(".")
        $currentVersionParts = $currentVersion.Split(".")

        $version = -1
        $stop = $false
        $i = 0
        do {
            $minPart = [int]$minVersionParts[$i]
            $currentPart = [int]$currentVersionParts[$i]
            $i += 1 
            if ( $currentPart -gt $minPart ) {
                $version = 1
                $stop = $true
            } elseif ( $currentPart -lt $minPart ) {
                $stop = $true
            } else {
                # version is equal, proceed
                # when it is the last step and equal, too -> success
                if ( $minVersionParts.count -eq $i ) {
                    $version = 0
                    $stop = $true
                }
            }
            
        } until ( $stop )

        <#
        $major = $versionParts[0]
        $minor = $versionParts[1]
        $revision = $versionParts[2]
        #>

    }
    
    end {

        $version -ge 0

    }

} 


<#

# This should return a string "ELAINE_ERROR_INVALID_INPUT"
Get-ELAINE-ErrorDescription -errCode "-18"

# This should return a string "Unknown Error"
Get-ELAINE-ErrorDescription -errCode "18"

#>
Function Get-ELAINE-ErrorDescription {

    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$true)][String] $errCode
    )

    begin {


    }
    
    process {

                
        $function = "api_errorCodes"
        $restParams = $script:defaultRestParams + @{
            Uri = "$( $script:apiRoot )$( $function )?&response=$( $script:settings.defaultResponseFormat )"
            Method = "Get"
        }
        $errorCodes = Invoke-RestMethod @restParams

        # Lookup a specific error code
        $errObj = $errorCodes | gm -MemberType NoteProperty | where { $_.Name -eq $errCode }
        if ( $errObj -ne $null ) { 
            $errDesc = $errObj.Definition.split("=")[1]
        } else {
            $errDesc = "Unknown Error"
        }
    }
    
    end {

        $errDesc

    }


}

<#
Required variables

$script:apiRoot
$script:defaultRestParams
$script:defaultRestParamsPost
$script:settings.defaultResponseFormat

# Call it like
Invoke-ELAINE -function "api_getElaineVersion"
Invoke-ELAINE -function "api_getElaineVersion" -parameters @($true)
Invoke-ELAINE -function "api_getElaineVersion" -parameters @($false)
Invoke-ELAINE -function "api_getElaineVersion" -parameters @($false) -method "Post"
Invoke-ELAINE -function "api_getElaineVersion" -parameters @($true) -method "Post" 

#>
Function Invoke-ELAINE {

    [CmdletBinding()]
    param (
          [Parameter(Mandatory=$true)][String] $function
         ,[Parameter(Mandatory=$false)][Microsoft.PowerShell.Commands.WebRequestMethod] $method = "Get"
         ,[Parameter(Mandatory=$false)][System.Collections.ArrayList] $parameters = $null
    )

    begin {
        if ( $parameters -ne $null ) {
            $param = "json=$( Format-ELAINE-Parameter $parameters )"
            #Set-Content -Value $param -Path "$( $scriptPath )\$( ([guid]::NewGuid()).guid ).txt"
        } else {
            $param = ""
        }
        $errorsToIgnore = @(-14, -12)
    }
    
    process {
        
        Switch ( $method.toString() ) {

            "Get" {
                
                $restParams = $script:defaultRestParams + @{
                    Uri = "$( $script:apiRoot )$( $function )?$( $param )&response=$( $script:settings.defaultResponseFormat )"
                    Method = "Get"
                }
            }

            "Post" {
                $restParams = $defaultRestParamsPost + @{
                    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
                    Body = $param
                }
                #$restParams.body | set-content -Path "$( $scriptPath )\$( [guid]::NewGuid().toString() ).json"
            }

            Default {
                throw [System.IO.InvalidDataException] "Method not implemented yet"  
            }

        }

        # Try the call multiple times if it fails
        $tries = 0
        $success = $false
        Do {

            try {

                #if ($tries -lt 2 ) {
                #    throw [System.Net.WebException] "Not found"
                #} 
                $result = Invoke-RestMethod @restParams
                $success = $true

            # Problem with the connection, retry
            } catch [System.Net.WebException] {

                Write-Log -message "Got a [System.Net.WebException] with status '$( $_.Exception.Status )' and reason '$( $_.Exception.Message )'" -severity ([LogSeverity]::ERROR)

                # If errored, wait a few seconds and increase tries
                Start-Sleep -Seconds 3
                $tries += 1

            }

        } until ( $tries -ge 3 -or $success)

        if ( $success ) {

            # Check if the result is an integer
            If ( Is-Int($result) ) {
                # If negative, it is definitely an error
                If ( $result -lt 0 ) {
                    If ( $errorsToIgnore -contains $result ) {
                        # Do nothing, those errors are created by blacklist entries or wrong email addresses
                    } else {
                        # Get the error description
                        $errMsg = "Got error '$( $result ) : $( Get-ELAINE-ErrorDescription -errCode $result )'"
                        Write-Log -message $errMsg
                        throw [System.IO.InvalidDataException] $errMsg  
                        $errMsg = ""
                    }
                }
            }
            
        }

    }
    
    end {

        $result

    }
}


<#
Needs the $settings object first with 
$settings.login.username
$settings.login.token
$settings.base
#>
Function Create-ELAINE-Parameters {

    [CmdletBinding()]
    param ()

    begin {

    }
    
    process {


        #-----------------------------------------------
        # AUTH
        #-----------------------------------------------

        # https://pallabpain.wordpress.com/2016/09/14/rest-api-call-with-basic-authentication-in-powershell/

        # Step 2. Encode the pair to Base64 string
        $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$( $settings.login.username ):$( Get-SecureToPlaintext $settings.login.token )"))
        
        # Step 3. Form the header and add the Authorization attribute to it
        $script:headers = @{ Authorization = "Basic $encodedCredentials" }

        
        #-----------------------------------------------
        # HEADER + CONTENTTYPE + BASICS
        #-----------------------------------------------

        $script:apiRoot = $settings.base
        $contentType = "application/json; charset=utf-8"

        $script:headers += @{

        }

        $script:defaultRestParams = @{
            Headers = $headers
            Verbose = $true
            ContentType = $contentType
        }

        $script:defaultRestParamsPost = @{
            Headers = $headers
            Verbose = $true
            Method = "Post"
            ContentType = "application/x-www-form-urlencoded"
        }

    }
    
    end {

    }

}

<#
- [ ] TODO Future Function to implement

function Match-ELAINE-Columns {

    [CmdletBinding()]

    param (
         [Parameter(Mandatory=$true)][String] $sourceColumns                  # array of csv column names
        ,[Parameter(Mandatory=$true)][String] $targetColumns                  # mixture of technical names and labels of fields
        ,[Parameter(Mandatory=$false)][String ]$prefixAdditionalColumns = "e_" # use this to create additional columns with e_ for groups or t_ for transactional mailings
    )

    begin {
        
    }

    process {
        # TODO [ ] implement this function
    }

    end {
        
    }

}
#>