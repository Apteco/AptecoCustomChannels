
<#
Requirements:
* This log needs the presence of two global variables
* Those variables do not need to be in this script, they can just be declared like
$logfile = "C:\logfile.txt"
$processId = [guid]::NewGuid()
* The process id is good for parallel calls so you know they belong together
#>

Function Write-Log {

    param(
         [Parameter(Mandatory=$true)][String]$message
    )

    # Create an array first for all the parts of the log message
    $logarray = @(
        [datetime]::UtcNow.ToString("yyyyMMddHHmmss")
        $processId
        $message
    )

    # Put the array together
    $logstring = $logarray -join "`t"

    # Save the string to the logfile
    $logstring | Out-File -FilePath $logfile -Encoding utf8 -Append -NoClobber

}
