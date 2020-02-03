
Function Write-Log {

    param(
         [Parameter(Mandatory=$true)][String]$message
    )

    "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`t$( $message )" | Out-File -FilePath $logfile -Encoding utf8 -Append -NoClobber

}