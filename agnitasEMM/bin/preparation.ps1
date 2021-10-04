
$securePassword = ConvertTo-SecureString (Get-SecureToPlaintext $settings.authentication.Password) -AsPlainText -Force
$cred = [System.Management.Automation.PSCredential]::new($settings.authentication.Username,$securePassword)
