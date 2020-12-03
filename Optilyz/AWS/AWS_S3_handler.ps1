Param(
    $uploadfile,
    $filename
)




# script root path
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $global:scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $global:scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

<#
$params = @($eventArgs.FullPath, $scriptPath)
        #write-host $params
        #Invoke-Command -ScriptBlock { Write-Host $args[1]  } -ArgumentList $params 
        Invoke-Command -ScriptBlock { & "$( $args[1] )\fs_login_and_export.ps1" -selectionFile "$( $args[0] )"  } -ArgumentList $params -Verbose
        #>


# build foldername and filename
$uploadfolder = "recipients/"
$uploadfolder += ( Import-Csv -path "$( $scriptPath )\messagenames.csv" -delimiter "`t" | where { $_.name -eq ( $filename -split "_" )[1] } | Select @{ name="directory";expression={ "$( $_._id )_$( $_.name  )" } } -First 1).directory
$uploadfolder += "/"
$uploadfilename = "$( [System.IO.Path]::GetFileName($uploadfile) )" -replace ".txt$",".csv"

# replace delimiter in text file
Get-Content $uploadfile -ReadCount 1000 -Encoding UTF8 | % { $_ -replace "`t","," } | Set-Content -Path "$( $uploadfile ).tmp" -Encoding UTF8
$uploadfile += ".tmp"


$params = @( $scriptPath, $uploadfile, $uploadfolder, $uploadfilename )
Invoke-Command -ScriptBlock { & "$( $args[0] )\s3_aws_upload.ps1" -operation "CREATEFOLDER" -uploadfile "" -uploadfolder "$( $args[2] )" -uploadfilename "" } -ArgumentList $params
Invoke-Command -ScriptBlock { & "$( $args[0] )\s3_aws_upload.ps1" -operation "UPLOADFILE" -uploadfile "$( $args[1] )" -uploadfolder "$( $args[2] )" -uploadfilename "$( $args[3] )" } -ArgumentList $params



