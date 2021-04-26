
Function Sanitize-FilenameSQLITE {

    param(
         [Parameter(Mandatory=$true)][String]$Filename
    )

    return $Filename -replace '\\','/'

}