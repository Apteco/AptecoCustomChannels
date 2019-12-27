################################################
#
# INPUT
#
################################################
<#
Param(
    [hashtable] $params
)
#>

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true

#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------
<#
if ( $debug ) {
    $params = [hashtable]@{
        scriptPath= "C:\FastStats\scripts\flexmail"
        MessageName= "1631416 | Testmail_2"
        abc= "def"
        ListName= "252060"
        Password= "def"
        Username= "abc" 
    }
}
#>


################################################
#
# NOTES
#
################################################



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

Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
$settingsFilename = "settings.json"

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        ,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

$logfile = $settings.logfile


################################################
#
# FUNCTIONS
#
################################################

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


################################################
#
# LOG INPUT PARAMETERS
#
################################################

<#
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t----------------------------------------------------" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tBROADCAST" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tGot a file with these arguments: $( [Environment]::GetCommandLineArgs() )" >> $logfile
$params.Keys | ForEach {
    $param = $_
    "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t $( $param ): $( $params[$param] )" >> $logfile
}
#>


################################################
#
# PROGRAM
#
################################################


#"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tUsing the recipient list $( $recipientListID )" >> $logfile


#-----------------------------------------------
# SETTINGS
#-----------------------------------------------

$sentsResponseTypes = [PSCustomObject]@{
    "campaignSent" = @{value="true";type="Boolean"}
    "campaignRead" = @{value="false";type="Boolean"}
    "campaignReadOnline" = @{value="false";type="Boolean"}
    "campaignLinkClicked" = @{value="false";type="Boolean"}
    "campaignLinkGroupClicked" = @{value="false";type="Boolean"}
    "campaignReadInfoPage" = @{value="false";type="Boolean"}
    "campaignFormVisited" = @{value="false";type="Boolean"}	
    "campaignFormSubmitted" = @{value="false";type="Boolean"}
    "campaignSurveyVisited" = @{value="false";type="Boolean"}
    "campaignSurveySubmitted" = @{value="false";type="Boolean"}
    "campaignForwardSubmitted" = @{value="false";type="Boolean"}
    "campaignForwardVisited" = @{value="false";type="Boolean"}
    "campaignNotSent" = @{value="false";type="Boolean"}
}

$opensResponseTypes = [PSCustomObject]@{
    "campaignSent" = @{value="false";type="Boolean"}
    "campaignRead" = @{value="true";type="Boolean"}
    "campaignReadOnline" = @{value="true";type="Boolean"}
    "campaignLinkClicked" = @{value="false";type="Boolean"}
    "campaignLinkGroupClicked" = @{value="false";type="Boolean"}
    "campaignReadInfoPage" = @{value="true";type="Boolean"}
    "campaignFormVisited" = @{value="false";type="Boolean"}	
    "campaignFormSubmitted" = @{value="false";type="Boolean"}
    "campaignSurveyVisited" = @{value="false";type="Boolean"}
    "campaignSurveySubmitted" = @{value="false";type="Boolean"}
    "campaignForwardSubmitted" = @{value="false";type="Boolean"}
    "campaignForwardVisited" = @{value="false";type="Boolean"}
    "campaignNotSent" = @{value="false";type="Boolean"}
}

$clicksResponseTypes = [PSCustomObject]@{
    "campaignSent" = @{value="false";type="Boolean"}
    "campaignRead" = @{value="false";type="Boolean"}
    "campaignReadOnline" = @{value="false";type="Boolean"}
    "campaignLinkClicked" = @{value="true";type="Boolean"}
    "campaignLinkGroupClicked" = @{value="true";type="Boolean"}
    "campaignReadInfoPage" = @{value="false";type="Boolean"}
    "campaignFormVisited" = @{value="false";type="Boolean"}	
    "campaignFormSubmitted" = @{value="false";type="Boolean"}
    "campaignSurveyVisited" = @{value="false";type="Boolean"}
    "campaignSurveySubmitted" = @{value="false";type="Boolean"}
    "campaignForwardSubmitted" = @{value="false";type="Boolean"}
    "campaignForwardVisited" = @{value="false";type="Boolean"}
    "campaignNotSent" = @{value="false";type="Boolean"}
}

$responseTypes = [HashTable]@{
    sents=$sentsResponseTypes
    opens=$opensResponseTypes
    clicks=$clicksResponseTypes
}

#-----------------------------------------------
# GET CAMPAIGN HISTORY
#-----------------------------------------------

if ( $debug ) {
    $campaigns = Invoke-Flexmail -method "GetCampaigns"
    $campaignArray = $campaigns | Out-GridView -PassThru # example id is: 7275152   
    $campaignArray = $campaignArray.campaignId
} else {
    $campaignsList = @("7275152")
    $campaignArray = $campaigns | Out-GridView -PassThru # example id is: 7275152    
}

#-----------------------------------------------
# LOAD RESPONSE DATA
#-----------------------------------------------


$responseTypes.Keys | ForEach {
    

    $responseTypeName = $_
    $responseTypeValue = $responseTypes[$responseTypeName]

    $campaignArray | ForEach {

        $historyParams = @{
            "campaignId"=@{
                "value"=$campaign.campaignId
                "type"="int"
             }
             "campaignHistoryOptionsType"=@{value=$responseTypeValue;type="campaignHistoryOptionsType"}
        }

        $campHistory = Invoke-Flexmail -method "GetCampaignHistory" -param $historyParams -verboseCall -responseType "EmailAddressHistoryActionType"

        switch ( $responseTypeName ) {
        
            "clicks" {
                $clicks += $campHistory | select @{name="campaignId";expression={ $campaign.campaignId }},
                            @{name="actionId";expression={ $_.actionId.InnerText }},
                            @{name="timestamp";expression={ $_.timestamp.InnerText }},
                            @{name="linkKey";expression={ $_.link.Key.InnerText }},
                            @{name="linkUrl";expression={ $_.link.value.InnerText }},
                            @{name="flexmailId";expression={ $_.emailAddressType.flexmailId.InnerText }},
                            @{name="emailAddress";expression={ $_.emailAddressType.emailAddress.InnerText }}
            }

            "opens" {
                
                $opens += $campHistory | select @{name="campaignId";expression={ $campaign.campaignId }},
                            @{name="actionId";expression={ $_.actionId.InnerText }},
                            @{name="timestamp";expression={ $_.timestamp.InnerText }},
                            @{name="flexmailId";expression={ $_.emailAddressType.flexmailId.InnerText }},
                            @{name="emailAddress";expression={ $_.emailAddressType.emailAddress.InnerText }}
                            
            }

            "sents" {
                
                $sents += $campHistory | select @{name="campaignId";expression={ $campaign.campaignId }},
                            @{name="actionId";expression={ $_.actionId.InnerText }},
                            @{name="timestamp";expression={ $_.timestamp.InnerText }},
                            @{name="flexmailId";expression={ $_.emailAddressType.flexmailId.InnerText }},
                            @{name="emailAddress";expression={ $_.emailAddressType.emailAddress.InnerText }}
                            
            }
                        
        }         
    }
}


#-----------------------------------------------
# EXPORT DATA
#-----------------------------------------------


$opens | Export-Csv -Path ".\opens.csv" -Encoding UTF8 -Delimiter "`t" -NoTypeInformation
$clicks | Export-Csv -Path ".\clicks.csv" -Encoding UTF8 -Delimiter "`t" -NoTypeInformation
$sents | Export-Csv -Path ".\sents.csv" -Encoding UTF8 -Delimiter "`t" -NoTypeInformation

