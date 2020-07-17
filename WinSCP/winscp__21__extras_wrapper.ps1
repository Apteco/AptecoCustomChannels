################################################
#
# INPUT
#
################################################

Param (

     [string]$fileToUpload
    ,[string]$scriptPath

)



################################################
#
# CALL
#
################################################

$params = [hashtable]@{
	Path = "$( $fileToUpload )"
    scriptPath = "$( $scriptPath )"
}

Set-Location -Path $scriptPath
.\winscp__20__upload.ps1 -params $params

