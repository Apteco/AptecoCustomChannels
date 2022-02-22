$t = Invoke-Flexmail -method "GetAccount" -param @{} -responseNode "account" -returnFlat

$t.language.'#text'

<#

# Switzerland
de

# UK
en

# Uzbekistan
en

#>

$c = Invoke-Flexmail -method "GetCampaigns" -param @{} -responseNode "campaignTypeItems"  -verboseCall


$t = Invoke-Flexmail -method "GetMailingLists" -param @{} -verboseCall -responseNode "mailingListTypeItems"  #-returnFlat #-responseNode "account"

$sourcesReturn = Invoke-Flexmail -method "GetSources" -responseNode "sources" #| where campaignType -eq Workflow
