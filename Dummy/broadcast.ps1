<#

Send (params)
    IntegrationParameters…
    Username
    Password
    ListName
    MessageName
    [… and anything returned from UPLOADSCRIPT]

Receive (Hashtable)
    Recipients
    TransactionId


#>

Param(
    [hashtable] $params
    # [Parameter(Position=1, ValueFromRemainingArguments)] $Remaining # The way to catch all input parameters into one variable "$Remaining"
)

<#
DynamicParam{
    
    $inputAttribute = New-Object System.Management.Automation.ParameterAttribute
    #$inputAttribute.Position = 1
    $inputAttribute.Mandatory = $true
    $inputAttribute.ParameterSetName = "params"

    $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
    $attributeCollection.Add($inputAttribute)


    $parameter = [System.Management.Automation.RuntimeDefinedParameter]::new("Input",[string],$attributeCollection)

    $paramDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
    $paramDictionary.Add("Input", $parameter)

    return $paramDictionary

}
#>

################################################
#
# SCRIPT ROOT
#
################################################


# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

$scriptPath = "C:\FastStats\scripts\esp\custom"

Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

$timestamp = [datetime]::Now.ToString("yyyyMMddHHmmss")
$logfile = "$( $scriptPath )\send-message.log"



################################################
#
# LOG INPUT PARAMETERS
#
################################################


"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t----------------------------------------------------" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tGot a file with these arguments: $( [Environment]::GetCommandLineArgs() )" >> $logfile
$params.Keys | ForEach {
    $param = $_
    "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t $( $param ): $( $params[$param] )" >> $logfile
}



<#
[PSCustomObject]@{
    TransactionId = "123";
    Recipients = 20;
}

@{
   TransactionId = "TId-" + $params.ListName;
   Recipients = 20;
}
#>