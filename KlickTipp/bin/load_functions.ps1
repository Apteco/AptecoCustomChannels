
# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

If ( $configMode -and -not $settings) {

    # Don't load yet, when in config mode and settings object not yet available

} else {
    
    # Load all exe files in subfolder
    $libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
    $libExecutables | ForEach {
        "... $( $_.FullName )"
    
    }

    # Load dll files in subfolder
    $libDlls = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
    $sqliteDll = $libDlls | where { $_.Name -eq $settings.sqliteDll } | select -first 1
    [Reflection.Assembly]::LoadFile( $sqliteDll.FullName )
    #$libDlls | ForEach {
    #    "Loading $( $_.FullName )"
    #    [Reflection.Assembly]::LoadFile($_.FullName) 
    #}

}


Add-Type -AssemblyName System.Security
