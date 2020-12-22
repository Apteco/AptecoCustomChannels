################################################
#
# INPUT
#
################################################

#Param(
#    [hashtable] $params
#)


#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true


################################################
#
# NOTES
#
################################################

<#

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
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$processId = [guid]::NewGuid()
$modulename = "TRMANUAL"
$timestamp = [datetime]::Now

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints = https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# Log
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & LIBRARIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

Add-Type -AssemblyName System.Security


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments = $( [Environment]::GetCommandLineArgs() )"

# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    $( $param ) = $( $params[$param] )"
    }
}


################################################
#
# PROCESS
#
################################################


#-----------------------------------------------
# CREATE HEADERS
#-----------------------------------------------

[uint64]$currentTimestamp = Get-Unixtime -timestamp $timestamp

# It is important to use the charset=utf-8 to get the correct encoding back
$contentType = $settings.contentType
$headers = @{
    "accept" = $settings.contentType
}


#-----------------------------------------------
# CREATE SESSION
#-----------------------------------------------

Get-TriggerDialogSession
#$jwtDecoded = Decode-JWT -token ( Get-SecureToPlaintext -String $Script:sessionId ) -secret $settings.authentication.authenticationSecret
$jwtDecoded = Decode-JWT -token ( Get-SecureToPlaintext -String $Script:sessionId ) -secret ( Get-SecureToPlaintext $settings.authentication.authenticationSecret )

$headers.add("Authorization", "Bearer $( Get-SecureToPlaintext -String $Script:sessionId )")


#-----------------------------------------------
# CHOOSE CUSTOMER ACCOUNT
#-----------------------------------------------
<#
if ( $jwtDecoded.payload.customerIds.Count -gt 1 ) {
    $customerId = $jwtDecoded.payload.customerIds | Out-GridView -PassThru
} elseif ( $jwtDecoded.payload.customerIds.Count -eq 1 ) {
    $customerId = $jwtDecoded.payload.customerIds[0]
} else {
    exit 0
}
#>
$customerId = $settings.customerId


#-----------------------------------------------
# WHAT TO DO?
#-----------------------------------------------

# operations
$operations = [ordered]@{

    "createcampaign"="create a new campaign"
    "createmailing"="create a new mailing"
    "createvariables"="create variables for a mailing"
    "createrecipients" = "upload recipient data"

    "listcampaigns"="just show all campaigns"
    "listmailings"="just show all mailings"
    "listvariables"="list variables of a mailing"
    "listaddressvariables"="lists address variables"
    "listrecipients"="list recipients of a campaign"
    "listtestrecipients"="list test recipients of a campaign"

    "showlookups" = "show contents of lookups"
    "showrecipientreport" = "show reports of a campaign at a day"

    "deletecampaign" = "delete a campaign"
    #"deletemailing" = "delete a mailing"

    "nothing"="nothing"
}

$operation = $operations | Out-GridView -PassThru | Select -First 1

Write-Log -message "Chosen the operation ""$( $operation.Key )"""


#-----------------------------------------------
# DO THE OPERATION
#-----------------------------------------------

#$newLists = @()
switch ( $operation.Key ) {

    <#
    ...
    #>
    "createcampaign" {

        #-----------------------------------------------
        # ASK FOR DATA
        #-----------------------------------------------

        $campaignIdExt = Read-Host -Prompt "External ID for new campaign"
        $campaignName = Read-Host -Prompt "Name for new campaign"


        #-----------------------------------------------
        # CREATE CAMPAIGN VIA REST
        #-----------------------------------------------

        $body = @{
            "campaignIdExt"= $campaignIdExt
            "campaignName"= $campaignName
            "customerId"= "$( $customerId )"
        }
        $bodyJson = $body | ConvertTo-Json
        Invoke-RestMethod -Method POST -Uri "$( $settings.base )/longtermcampaigns" -Verbose -Headers $headers -ContentType $contentType -Body $bodyJson

    }

    "deletecampaign" {

        #-----------------------------------------------
        # LIST CAMPAIGNS
        #-----------------------------------------------

        $campaignDetails = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/longtermcampaigns?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $campaign = $campaignDetails.elements | Out-GridView -PassThru | select -first 1


        #-----------------------------------------------
        # DELETE CAMPAIGN VIA REST
        #-----------------------------------------------

        Invoke-RestMethod -Method Delete -Uri "$( $settings.base )/longtermcampaigns/$( $campaign.id )?customerId=$( $customerId  )" -Verbose -Headers $headers -ContentType $contentType #-Body $bodyJson

    }

    <#
    ...
    #>
    "createmailing" {

        #-----------------------------------------------
        # LIST CAMPAIGNS
        #-----------------------------------------------


        $campaignDetails = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/longtermcampaigns?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $campaign = $campaignDetails.elements | Out-GridView -PassThru | select -first 1


        #-----------------------------------------------
        # CREATE MAILING VIA REST
        #-----------------------------------------------

        $body = @{
            "campaignId"= $campaign.id
            "customerId"= "$( $customerId )"
        }
        $bodyJson = $body | ConvertTo-Json
        $newMailing = Invoke-RestMethod -Method Post -Uri "$( $settings.base )/mailings" -Verbose -Headers $headers -ContentType $contentType -Body $bodyJson

        #-----------------------------------------------
        # UPDATE SENDER VIA REST
        #-----------------------------------------------
        
        <#
        $body = @{
            "customerId"= "customerABC"
            "senderAddress"= "senderABC"
        }
        $bodyJson = $body | ConvertTo-Json
        Invoke-RestMethod -Method Put -Uri "$( $settings.base )/mailings/$( $newMailing.id )/" -Verbose -Headers $headers -ContentType $contentType -Body $bodyJson
        #>

    }

    <#
    ...
    
    "deletemailing" {
    
        # can also be narrowed down to a campaign via &campaignId=xyz
        $mailingDetails = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/mailings?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $mailing = $mailingDetails.elements | Out-GridView -PassThru

        #-----------------------------------------------
        # DELETE CAMPAIGN VIA REST
        #-----------------------------------------------

        Invoke-RestMethod -Method Delete -Uri "$( $settings.base )/longtermcampaigns/$( $mailing.id )?customerId=$( $customerId  )" -Verbose -Headers $headers -ContentType $contentType #-Body $bodyJson


    }
#>


    <#
    ...
    #>
    "createvariables" {

        #-----------------------------------------------
        # LIST MAILINGS
        #-----------------------------------------------

        # choose a mailing
        $mailingDetails = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/mailings?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $mailing = $mailingDetails.elements | Out-GridView -PassThru | select -first 1


        #-----------------------------------------------
        # CREATE FIELDS VIA REST
        #-----------------------------------------------

        <#
        dataTypeIds can be found in the lookups
        id label
        -- -----
        10 Text
        20 Ganzzahl
        30 Boolscher Wert
        40 Datum
        50 Bild
        60 Bild-URL
        70 Fließkommazahl
        80 Postleitzahl
        90 Ländercode
        
        required fields are zip and city

        #>

        $body = @{
            "customerId" = $customerId
            "createVariableDefRequestRepList" = @(
                @{
                    "label" = "city"
                    "sortOrder" = 20
                    #"x" = 0
                    #"y" = 0
                    #"font" = 0
                    #"fontSize" = 0
                    #"spanHeight" = 0
                    "dataTypeId" = 10
                },
              @{
                "label" = "zip"
                "sortOrder" = 10
                #"x" = 0
                #"y" = 0
                #"font" = 0
                #"fontSize" = 0
                #"spanHeight" = 0
                "dataTypeId" = 80
              }
            )
        }
        $bodyJson = $body | ConvertTo-Json
        $newVariables = Invoke-RestMethod -Method Post -Uri "$( $settings.base )/mailings/$( $mailing.id )/variabledefinitions" -Verbose -Headers $headers -ContentType $contentType -Body $bodyJson
        $newVariables.elements | Out-GridView

    }


    "createrecipients" {

        #-----------------------------------------------
        # LIST CAMPAIGNS
        #-----------------------------------------------

        $campaignDetails = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/longtermcampaigns?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $campaign = $campaignDetails.elements | Out-GridView -PassThru | select -first 1


        #-----------------------------------------------
        # CREATE RECIPIENTS
        #-----------------------------------------------

        $body = @{
            "campaignId" = $campaign.id
            "customerId" = $customerId
            "recipients" = @(
                
                # This is the data of 1 recipient
                @{
                    "recipientData" = @(                    
                        @{
                            "label" = "zip"
                            "value" = "48309"
                        }
                        @{
                            "label" = "city"
                            "value" = "Dover"
                        }
                    )
                    "recipientIdExt" = "null"
                },

                # This is the data of 1 recipient
                @{
                    "recipientData" = @(                    
                        @{
                            "label" = "zip"
                            "value" = "52080"
                        }
                        @{
                            "label" = "city"
                            "value" = "Aachen"
                        }
                    )
                    "recipientIdExt" = "null"
                }
                


            )
        }

        $bodyJson = $body | ConvertTo-Json -Depth 8
        $newCustomers = Invoke-RestMethod -Method Post -Uri "$( $settings.base )/recipients" -Verbose -Headers $headers -ContentType $contentType -Body $bodyJson
        $newCustomers.elements | Out-GridView

        <#
        
        If uploaded failed, you get an http422

        If succeeded, you a correlationId back
        
        id on a upload at 2020-10-14: d7513861-894b-4b8b-b88e-34e992f0c1ba

        #>

        # Send back id
        $newCustomers.correlationId
        
    }
    
    "showrecipientreport" {

        # TODO [ ] not successfully used yet

        #-----------------------------------------------
        # LIST CAMPAIGNS
        #-----------------------------------------------

        $campaignDetails = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/longtermcampaigns?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $campaign = $campaignDetails.elements | Out-GridView -PassThru | select -first 1


        #-----------------------------------------------
        # SHOW REPORT
        #-----------------------------------------------

        # Maybe use accept header :  text/csv
        $reportDate = "2020-10-14"
        $report = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/recipientreport/detail?campaignId=$( $campaign.id )&customerId=$( $customerId )&reportDate=$( $reportDate )" -Verbose -Headers $headers -ContentType $contentType
        $report

    }

    "showlookups" {

        <#
        MailingTemplateType

        id label
        -- -----
        110 Basic-Editor nur Adressen
        120 Basic-Editor begrenzte Individualisierung
        210 Advanced-Editor nur Adressen
        220 Advanced-Editor begrenzte Individualisierung
        230 Advanced-Editor volle Individualisierung

        #>

        # Load lookups
        $mailingLookups = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/mailinglookups?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $mailingLookups.elements | Out-GridView

        # Show choice of lookups
        $lookups = $mailingLookups | gm -type NoteProperty | Select name | Out-GridView -PassThru

        # Show details of lookups
        $lookups | foreach {
            $detail = $_
            $mailingLookups.($detail.name) | Out-GridView
        }

    }

    <#
    ...
    #>
    "listcampaigns" {
       
        $campaignDetails = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/longtermcampaigns?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $campaignDetails.elements | Out-GridView

    }

    <#
    ...
    #>
    "listmailings" {
       
        # can also be narrowed down to a campaign via &campaignId=xyz
        $mailingDetails = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/mailings?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $mailingDetails.elements | Out-GridView

    }

    <#
    ...
    #>
    "listvariables" {
       
        # choose a mailing
        $mailingDetails = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/mailings?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $mailing = $mailingDetails.elements | Out-GridView -PassThru | select -first 1

        # can also be narrowed down to a campaign via &campaignId=xyz
        $variableDefinitions = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/mailings/$( $mailing.id )/variabledefinitions?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $variableDefinitions.elements | Out-GridView

    }

    "listaddressvariables" {
       
        <#
        id createdOn                changedOn                version name         sortOrder synonyms
        -- ---------                ---------                ------- ----         --------- --------
        1 2019-11-18T16:16:26.000Z 2019-11-18T16:16:26.000Z       1 Firma               10 Firmenname,Company,Unternehmen,Firma,Company name
        11 2020-11-25T17:21:05.000Z                                0 Firma 2             12 Firmenname 2,Company 2,Unternehmen 2
        12 2020-11-25T17:21:05.000Z                                0 Firma 3             14 Firmenname 3,Company 3,Unternehmen 3
        2 2019-11-18T16:16:26.000Z                                0 Anrede              20 salutation,Anrede
        3 2019-11-18T16:16:26.000Z                                0 Titel               30 title,Titel
        4 2019-11-18T16:16:26.000Z 2019-11-18T16:16:26.000Z       1 Vorname             40 firstname,first name,first_name,Vorname
        5 2019-11-18T16:16:26.000Z 2019-11-18T16:16:26.000Z       1 Nachname            50 surname,lastname,last name,Name,family name,last_name,family_name,Nachname
        13 2020-11-25T17:21:05.000Z                                0 Adresszusatz        55 Additional address,Address suffix,Address supplement,address addendum
        6 2019-11-18T16:16:26.000Z 2019-11-18T16:16:26.000Z       1 Straße              60 Strasse,str,str.,street,st.,road,Straße,Street address
        7 2019-11-18T16:16:26.000Z 2019-11-18T16:16:26.000Z       1 Hausnummer          70 hnr,hausnr.,hausnr,haus-nr,haus nr.,Haus-Nummer,Hausnummer,Haus_Nr,Haus_Nr.,Haus_Nummer,house number,house no,house_number,street number,Haus-Nr.,numm...
        10 2019-11-18T16:16:26.000Z 2019-11-18T16:16:26.000Z       1 Postfach            75 post office box,po box,post_office_box,box number,po_box,box_number,Postfach
        8 2019-11-18T16:16:26.000Z                                0 PLZ                 80 Postleitzahl,zip,zip code,zip-code,PLZ
        9 2019-11-18T16:16:26.000Z 2019-11-18T16:16:26.000Z       1 Ort                 90 Wohnort,Stadt,city,Gemeinde,municipality,Ort        
        #>

        # can also be narrowed down to a campaign via &campaignId=xyz
        $addressvariables = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/mailings/addressvariables?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $addressvariables.elements | Out-GridView

    }

    "listrecipients" {
        
        # choose a campaign
        $campaignDetails = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/longtermcampaigns?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $campaign = $campaignDetails.elements | Out-GridView -PassThru | select -first 1

        # get recipients for a campaign
        # can also be narrowed down by
        #   recipientPackageId int
        #   testData true|false
        #   hasRecipientPackage true|false
        $recipients = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/recipients?customerId=$( $customerId )&campaignId=$( $campaign.id )" -Headers $headers -ContentType $contentType -Verbose
        $recipients.elements | Out-GridView

    }

    "listtestrecipients" {
       
        # choose a campaign
        $campaignDetails = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/longtermcampaigns?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose
        $campaign = $campaignDetails.elements | Out-GridView -PassThru | select -first 1

        # get recipients for a campaign
        # can also be narrowed down by
        #   recipientPackageId int
        #   testData true|false
        #   hasRecipientPackage true|false
        $recipients = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/recipients?customerId=$( $customerId )&campaignId=$( $campaign.id )&testData=true" -Headers $headers -ContentType $contentType -Verbose
        $recipients.elements | Out-GridView
        $campaignDetails.elements | Out-GridView

    }



}

#[void](Read-Host 'Press Enter to continue…')

exit 0
<#


    "copy" {
    
        #-----------------------------------------------
        # LOAD ALL LISTS AND CREATE NEW ONES
        #-----------------------------------------------

        $recipientLists = Get-EpiRecipientLists 

        $recipientListsForCopy = $recipientLists | Out-GridView -PassThru

        $newIDs = @()
        $recipientListsForCopy | ForEach {
            
            # create new recipient list
            $recipientList = $_
            $newID = Invoke-Epi -webservice "RecipientList" -method "copy" -param @(@{value=$recipientList.id;datatype="long"}) -useSessionId $true
            $newIDs += $newID

            # get the name of the original list
            $originalrecipientListName = Invoke-Epi -webservice "RecipientList" -method "getName" -param @(@{value=$recipientList.id;datatype="long"}) -useSessionId $true

            # set the name of the new list
            $newName = Read-Host -Prompt "New name for copy of '$( $originalrecipientListName )'"
            Invoke-Epi -webservice "RecipientList" -method "setName" -param @(@{value=$newID;datatype="long"},@{value=$newName;datatype="String"}) -useSessionId $true

            # Log the result
            "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tCopying the list ""$( $recipientList.id )"" with name ""$( $originalrecipientListName )"" to new ID ""$( $newID )"" with name ""$( $newName )""" >> $logfile
 

        }

        # load recipient lists again after copying
        $recipientLists = Get-EpiRecipientLists 

        $newLists = $recipientLists | where { $_.id -in $newIDs } | select id, 'ID-Feld'
        
        # Log the result
        "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tCreated the new lists $( $newLists.id -join ',' )" >> $logfile

    }


    "add" {
        
        # Load all lists
        $recipientLists = Get-EpiRecipientLists 

        # Promp the user to select the ones to add
        $newLists = $recipientLists | Out-GridView -PassThru | select id, 'ID-Feld'

        # Log the result
        "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tAdding the lists $( $newLists.id -join ',' )" >> $logfile

    }


    "rename" {
        
        # Load all lists
        $recipientLists = Get-EpiRecipientLists 

        # Promp the user to select the ones to rename
        $changeNames = $recipientLists | Out-GridView -PassThru

        # Ask for every single list in the selection
        $changeNames | ForEach {
            
            # create new recipient list
            $recipientListID = $_.id
            $recipientListName = $_.Name

            # set the name of the new list
            $newName = Read-Host -Prompt "New name for list '$( $recipientListID )' - '$( $recipientListName )'"
            Invoke-Epi -webservice "RecipientList" -method "setName" -param @(@{value=$recipientListID;datatype="long"},@{value=$newName;datatype="String"}) -useSessionId $true

            # Log the result
            "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tChanged the name online for List $( $recipientListID ) from ""$( $recipientListName )"" to ""$( $newName )""" >> $logfile

        }

        # Log the result
        "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tChanged the names online for lists $( $changeNames.id -join ',' )" >> $logfile

    }

 
    "show" {
        
        # Load all lists
        $recipientLists = Get-EpiRecipientLists 
        
        # Show them
        $recipientLists | Out-GridView 

    }


    "remove" {
        
        # Load all lists
        $recipientLists = Get-EpiRecipientLists 
        
        # Show them
        $removeLists = $recipientLists | where { $_.id -in $existingRecipientLists.id } | Out-GridView -PassThru

        $existingRecipientLists = $existingRecipientLists | where { $_.id -notin $removeLists.id }

        # Log the result
        "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tRemoved the lists locally $( $removeLists.id -join ',' )" >> $logfile

    }


    "addDescription" {

        # Load all lists    
        $recipientLists = Get-EpiRecipientLists 

        # Select the ones to rename
        $changeNames = $recipientLists | Out-GridView -PassThru

        # Change each description
        $changeNames | ForEach {
            
            # create new recipient list
            $recipientListID = $_.ID
            $recipientListName = $_.Name
            $recipientListDescription = $_.Description

            # set the name of the new list
            $newDescription = Read-Host -Prompt "New description for list '$( $recipientListID )' - '$( $recipientListName )' - '$( $recipientListDescription )'"
            Invoke-Epi -webservice "RecipientList" -method "setDescription" -param @(@{value=$recipientListID;datatype="long"},@{value=$newDescription;datatype="String"}) -useSessionId $true

            # Log the result
            "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tChanged the description online for List $( $recipientListID ) from ""$( $recipientListDescription )"" to ""$( $newDescription )""" >> $logfile

        }

        # Log the result
        "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tChanged the descriptions online for lists $( $changeNames.id -join ',' )" >> $logfile


    }

#>