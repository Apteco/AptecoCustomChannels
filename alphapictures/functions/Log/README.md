
# Set the logfile

Something like

```PowerShell
$logfile = $settings.logfile
```

# Debug mode

Normally I use a settings at the beginning of the script like:

```PowerShell
# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}
```

# Write the log

Example of writing the log

```PowerShell 
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"
```

# Write a file for a virtual variable
Create an integration parameter in the channel editor with something like `importFile=D:\Apteco\Publish\Handel\Public\alphapictures.csv`