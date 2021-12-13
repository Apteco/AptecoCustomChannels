
# Define some enums
Enum psdb {
    SQLITE = 10
    POSTGRES = 20
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

    switch ($settings.dbtype) {

        { $_ -eq [psdb]::POSTGRES } { 
    
            $postgresDll = $libDlls | where { $_.Name -eq $settings.postgresDll } | select -first 1
            [Reflection.Assembly]::LoadFile( $postgresDll.FullName )

            #[Reflection.Assembly]::LoadFile(( $libDlls | where { $_.Name -eq "System.Threading.Tasks.Extensions" } | select -first 1 ))
            #[Reflection.Assembly]::LoadFile(( $libDlls | where { $_.Name -eq "System.Runtime.CompilerServices.Unsafe" } | select -first 1 ))
    
         }
    
        # Otherwise just use sqlite
        Default {
    
            $sqliteDll = $libDlls | where { $_.Name -eq $settings.sqliteDll } | select -first 1
            [Reflection.Assembly]::LoadFile( $sqliteDll.FullName )
            
        }
        
    }
    #$libDlls | ForEach {
    #    "Loading $( $_.FullName )"
    #    [Reflection.Assembly]::LoadFile($_.FullName) 
    #}

}