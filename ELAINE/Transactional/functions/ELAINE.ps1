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
