Function Format-ELAINE-Parameter {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [Array]
        $arr
    )

    begin {
        
    }
    
    process {
        $json = ConvertTo-Json $arr -Compress # `$json | convertto-json` does not work properly with single elements
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
                throw [System.IO.InvalidDataException] "No ELAINE version loaded into cache through environment. Please define in script '`$elaineVersion' or use parameter -currentVersion"
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