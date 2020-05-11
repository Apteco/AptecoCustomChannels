
################################################
#
# SCRIPT ROOT
#
################################################


# script root path
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript")
{ $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition }
else
{ $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0]) }


################################################
#
# SALESFORCE
#
################################################

$uri = [PSCustomObject]@{
    resource='https://eu9.salesforce.com';
    authUri='https://login.salesforce.com/services/oauth2/authorize';
    tokenUri='https://login.salesforce.com/services/oauth2/token';
    testUri='https://eu9.salesforce.com/services/data/v41.0/sobjects';
    redirectUri = 'https://www.getpostman.com/oauth2/callback';
    endpoint= 'https://eu9.salesforce.com/services/data/v41.0/'
}

$authentication = [PSCustomObject]@{
    clientid = '<clientid>'
    clientSecret = '<clientsecret>';
    scope = 'api refresh_token offline_access'
}

$sobjects = @()
$sobjects += [PSCustomObject]@{
    B2B=@("Account";"Contact");
    B2C=@("Account";"Order";"OrderItem")
}

$salesforce = [pscustomobject]@{
    uri=$uri;
    authentication=$authentication;
    sobjects=$sobjects  
}




################################################
#
# LOAD SETTINGS
#
################################################

$load = [pscustomobject]@{
    method = 'QUERY'; # QUERY|BATCH
    concurrentCalls = 10;
    selectionColumnName = "selectedItems";
    checkboxColumnName = "Selection";
    sobjectsFirstFields = @("name";"label";"custom";"endpoint");
    describeFirstFields = @("name";"label";"compoundFieldName";"type";"extraTypeInfo";"deprecatedAndHidden";"custom";"calculated";"byteLength";"precision")
    
}


################################################
#
# GENERAL SETTINGS
#
################################################

$general = [pscustomobject]@{
    iconSource = "C:\Program Files\Apteco\FastStats Designer\FastStats Designer.exe";
    windowTitle = "Connect Apteco Marketing Suite with Force.com Lightning Platform REST API";
    xamlAuth = "$( $scriptPath )\views\oauth.xaml";
    xamlConfig = "C:\Users\Florian\source\repos\WpfApp5\WpfApp5\MainWindow.xaml"#"$( $scriptPath )\views\config.xaml";
    hidePowerShell = $true;
    useApplicationContext=$true; # for more performance in the UI
    templateTabName="Template";
    filterAfterMilliseconds = 300;
    filterTickDuration = 100;
    soqlPattern = '(?<=SELECT\s)(.*)(?=\sFROM)';
    throttle = 1
}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################


$settings = [pscustomobject]@{
    salesforce=$salesforce;
    general=$general;
    load=$load
}

$json = $settings | ConvertTo-Json -Depth 8 # -compress

$json

$json | Set-Content -path "$( $scriptPath )\settings.json" -Encoding UTF8



