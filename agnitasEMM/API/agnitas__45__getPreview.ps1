################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $false


#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
        scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\agnitasEMM\API"
        TestRecipient= '{"Email":"florian.von.bracht@apteco.de","Sms":null,"Personalisation":{"Kunden ID":"Kunden ID","Vorname":"Vorname","Nachname":"Nachname","Anrede":"Anrede","Communication Key":"b7047c1c-2c70-4789-8c6c-74a7759b1ec3"}}'
        MessageName = '773320 | Skate'
        ListName= '773320 | Skate'
        Password= "gutentag"
        Username= "absdede"
    }
}



################################################
#
# NOTES
#
################################################

<#

https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Mailing-getMailings

#>

################################################
#
# SCRIPT ROOT
#
################################################

# if debug is on a local path by the person that is debugging will load
# else it will use the param (input) path
if ( $debug ) {
    # Load scriptpath
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    } else {
        $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    }
} else {
    $scriptPath = "$( $params.scriptPath )" 
}
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

$script:moduleName = "AGNITAS-RENDER-PREVIEW"

try {

    # Load general settings
    . ".\bin\general_settings.ps1"

    # Load settings
    . ".\bin\load_settings.ps1"

    # Load network settings
    . ".\bin\load_networksettings.ps1"

    # Load functions
    . ".\bin\load_functions.ps1"

    # Start logging
    . ".\bin\startup_logging.ps1"

    # Load preparation ($cred)
    . ".\bin\preparation.ps1"

} catch {

    Write-Log -message "Got exception during start phase" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ( [LogSeverity]::ERROR )
    
    throw $_.exception  

    exit 1

}


################################################
#
# PROGRAM
#
################################################


#-----------------------------------------------
# STEP 2: Check if Mailing is valid
#-----------------------------------------------

$mailingParsed = [Mailing]::new($params.MessageName)
$invokeParams = [Hashtable]@{
    Method = "Get"
    Uri = "$( $apiRoot )/mailing/$( [int]$mailingParsed.mailingId )"
    Headers = $header
    Verbose = $true
    ContentType = $contentType
}
$mailing = Invoke-RestMethod @invokeParams
$mailingMediatypes = $mailing.mediatypes | where { $_.type -eq "EMAIL" }

<#
Name                    MemberType   Definition
----                    ----------   ----------
company_id              NoteProperty int company_id=3075
components              NoteProperty Object[] components=System.Object[]
contents                NoteProperty Object[] contents=System.Object[]
creation_date           NoteProperty string creation_date=2021-09-24T09:29:56+02
description             NoteProperty string description=Skating for everyone
grid                    NoteProperty System.Management.Automation.PSCustomObject grid=@{template=; grid=; div_children=System.Object[]; divcontainers=System.Object[]; mediapool=System.Object[]; categories=System.Object[]}
id                      NoteProperty int id=773320
links                   NoteProperty Object[] links=System.Object[]
mailinglist_description NoteProperty string mailinglist_description=Standard ... NICHT LÃSCHEN!!!...
mailinglist_id          NoteProperty int mailinglist_id=32652
mailinglist_shortname   NoteProperty string mailinglist_shortname=Standard-Liste
mailingtype             NoteProperty string mailingtype=NORMAL
mailing_content_type    NoteProperty string mailing_content_type=advertising
mediatypes              NoteProperty Object[] mediatypes=System.Object[]
shortname               NoteProperty string shortname=Skate
version                 NoteProperty string version=1.1.0
#>


#-----------------------------------------------
# PARSING TEST RECIPIENT
#-----------------------------------------------

# Parse preview recipient
$testRecipient = ConvertFrom-Json -InputObject $params.TestRecipient
$recipientFields = @( ( $testRecipient.Personalisation | Get-Member -MemberType NoteProperty ).Name ) # + ( $testRecipient | Get-Member -MemberType NoteProperty | where { $_.Name -ne "Personalisation" } ).Name )


#--------------------------------------------------------
# STEP 3: Compare Fields as a log entry
#-------------------------------------------------------- 
<#
    https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Mailinglist-mailinglistMailinglistIdRecipientsGet
#>

# Get fields from EMM
$mailinglistRecipients = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )/mailinglist/$( $settings.upload.standardMailingList )/recipients" -Headers $header -ContentType $contentType -Verbose

# Reading the columns of Agnitas EMM only works if you have one receiver as minimum
if ( $mailinglistRecipients.recipients.count -gt 0 ) {

    # Get properties/fields from agnitas
    $agnitasFields = ( $mailinglistRecipients.recipients | Get-Member -MemberType NoteProperty ).Name

    # Get fields from PeopleStage
    $csvColumns = $recipientFields

    $fieldComparation = Compare-Object -ReferenceObject $agnitasFields -DifferenceObject $csvColumns -IncludeEqual
    $equalColumns = ( $fieldComparation | where { $_.SideIndicator -eq "==" } ).InputObject
    $columnsOnlyCsv = ( $fieldComparation | where { $_.SideIndicator -eq "=>" } ).InputObject
    $columnsOnlyEMM = ( $fieldComparation | where { $_.SideIndicator -eq "<=" } ).InputObject

    Write-Log -message "Equal columns: $( $equalColumns -join ", " )"
    Write-Log -message "Columns only CSV: $( $columnsOnlyCsv -join ", " )"
    Write-Log -message "Columns only EMM: $( $columnsOnlyEMM -join ", " )"

} else {

    Write-Log -message "No receiver in Agnitas EMM avaible yet to read the available columns" -severity ( [LogSeverity]::WARNING )

}


#-----------------------------------------------
# CREATE A RECIPIENT
#-----------------------------------------------

<#

https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Recipient-recipientPut

Date-time of creation (ISO-8601). Only for read methods. Items to create or update may not have a creation_date.
example: 2017-07-21T17:32:28Z 

query - all optional
mailinglist
status #Subscription status of recipient. (Active(1), Bounce(2), AdminOut(3), UserOut(4), WaitForConfirm(5), Blacklisted(6), Suspend(7)), needs parameter mailinglist, default active 
mediaType #EMAIL (0), POST (2), SMS (2), needs parameter mailinglist, default EMAIL 
#>

$body = [Hashtable]@{}
$body.Add( "email", $testRecipient.Email )
$equalColumns | ForEach {
    $body.Add( $_, $testRecipient.Personalisation.$_ )
}
<#
@{
    email = $testRecipient.Email  # mandatory
    firstname = $testRecipient.Personalisation.Vorname
    lastname = $testRecipient.Personalisation.Nachname
    #creation_date = ""
}#>

$invokeParams = [Hashtable]@{
    Method = "Put"
    Uri = "$( $apiRoot )/recipient?mailinglist=$( $settings.upload.standardMailingList )&status=1&mediaType=0"
    Headers = $header
    Verbose = $true
    ContentType = $contentType
    Body =  ConvertTo-Json -InputObject $body -Depth 99 -Compress
}
$putRecipient = Invoke-RestMethod @invokeParams

# Logging for test recipient
Write-Log -message "Created a test receiver with following data:"
$putRecipient | Get-Member -MemberType NoteProperty | ForEach {
    $propName = $_.Name
    Write-Log -message "  $( $propName ) = $( $putRecipient.$propName )"
}


#-----------------------------------------------
# DECLARE RECIPIENT AS TEST RECIPIENT
#-----------------------------------------------

# Adding binding as a test receiver
$invokeParams = [Hashtable]@{
    Method = "Put"
    Uri = "$( $apiRoot )/binding/$( $putRecipient.customer_id )"
    Headers = $header
    Verbose = $true
    ContentType = $contentType
    Body = @{
        mailinglist_id = $settings.upload.standardMailingList  # mandatory
        user_status = 1 # 1=active; mandatory
        user_type = "T" # T=TEST_RECIPIENT
        #creation_date = ""
    } | ConvertTo-Json -Depth 99 -Compress
}
$putBinding = Invoke-RestMethod @invokeParams

Write-Log -message "Result of put binding on test receiver: '$( $putBinding )'"


<#
# Test for reading that recipient
$invokeParams = [Hashtable]@{
    Method = "Get"
    Uri = "$( $apiRoot )/recipient/$( $putRecipient.customer_id )"
    Headers = $header
    Verbose = $true
    ContentType = $contentType
}
$getRecipient = Invoke-RestMethod @invokeParams

#>


#-----------------------------------------------
# CREATE PREVIEW
#-----------------------------------------------


# Create fullview URL
# https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Url-urlFullviewPost

$invokeParams = [Hashtable]@{
    Method = "Post"
    Uri = "$( $apiRoot )/url/fullview"
    Headers = $header
    Verbose = $true
    ContentType = $contentType
    Body = @{
        customerID = $putRecipient.customer_id
        mailingID = $mailing.id
        formName = "fullview"
        #other_values = ""
    } | ConvertTo-Json -Depth 99 #-Compress
}
$putPreview = Invoke-RestMethod @invokeParams

$previewContent = Invoke-RestMethod -uri $putPreview -Method get -Verbose

# PARSE URL AND OUTPUT

#-----------------------------------------------
# DELETE RECIPIENT
#-----------------------------------------------

$invokeParams = [Hashtable]@{
    Method = "Delete"
    Uri = "$( $apiRoot )/recipient/$( $putRecipient.customer_id )"
    Headers = $header
    Verbose = $true
    ContentType = $contentType
}
$deleteRecipient = Invoke-RestMethod @invokeParams

Write-Log -message "Result of deleting test receiver: '$( $deleteRecipient )'"


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# return object
$return = [Hashtable]@{
    "Type" = "Email" #Email|Sms
    "FromAddress"=$mailingMediatypes.from_address
    "FromName"=$mailingMediatypes.from_fullname
    "Html"=$previewContent
    "ReplyTo"=$mailingMediatypes.reply_address
    "Subject"=$mailingMediatypes.subject
    "Text"=""
}

# return the results
$return