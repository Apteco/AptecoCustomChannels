
$securePassword = ConvertTo-SecureString (Get-SecureToPlaintext $settings.authentication.SOAP.password) -AsPlainText -Force
$cred = [System.Management.Automation.PSCredential]::new($settings.authentication.SOAP.username,$securePassword)
