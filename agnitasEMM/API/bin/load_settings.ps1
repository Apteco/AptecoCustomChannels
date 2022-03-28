# Load settings
$settings = Get-Content -Path $settingsFilename -Encoding UTF8 -Raw | ConvertFrom-Json #"$( $scriptPath )\$( $settingsFilename )"

#-----------------------------------------------
# ADD SOME SETTINGS
#-----------------------------------------------

# TODO [ ] put those later in the settings creation script
$settings | Add-Member -MemberType NoteProperty -Name "fergeExe" -Value "C:\Program Files\Apteco\FastStats Email Response Gatherer x64\EmailResponseGatherer64.exe"
$settings | Add-Member -MemberType NoteProperty -Name "fergeConfig" -Value "D:\Apteco\scripts\response_gathering\espconfig.xml"
$settings | Add-Member -MemberType NoteProperty -Name "detailsSubfolder" -Value ".\detail_log"
