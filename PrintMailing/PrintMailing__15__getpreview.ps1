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
        scriptPath = 'D:\Scripts\TriggerDialog\v2'
        TestRecipient = '{"Email":"testrecipient@example.com","Sms":null,"Personalisation":{"Test":"Contentobjekt","Kunden ID":"Kunden ID","Anrede":"Anrede","Vorname":"Vorname","Nachname":"Nachname","Strasse":"Strasse","PLZ":"PLZ","Ort":"Ort","TTT":"GGG","Geburtsdatum":"Geburtsdatum","Communication Key":"ab0ba429-4be7-45b7-bcc5-de9eaa72e23b"}}'
        MessageName = '41125 / 36145 / 2020-12-22_00:36:52 / Entwurf / EDIT'
        ListName = '41125 / 36145 / 2020-12-22_00:36:52 / Entwurf / EDIT'
        Password = 'b'
        Username = 'a'
    }
}


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

# General settings
$modulename = "TRPREVIEW"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"


################################################
#
# PROCESS
#
################################################

#-----------------------------------------------
# PARSE PREVIEW PARAMS (JSON)
#-----------------------------------------------

$testData = $params.TestRecipient | ConvertFrom-Json

<#
# This results in an object like
$testData = @{
    "Email"="name@example.com"
    "Sms" = "null"
    "Personalisation" =  @{
        "Kunden ID" = "Kunden ID"
        "Anrede" = "Anrede"
        "Vorname" = "Vorname"
        "Nachname" = "Nachname"
        "Strasse" = "Strasse"
        "PLZ" = "PLZ"
        "Ort" = "Ort"
        "Communication Key" = "f77ae8ff-5a2c-4e3a-9dc0-4add510d222f"
    }
}
#>

#-----------------------------------------------
# PARSE MESSAGE NAME
#-----------------------------------------------

$message = [TriggerDialogMailing]::new($params.MessageName)

$changeCampaignName = $false
# If ListName is something other than messagename, use this for the campaign name
if ( $params.ListName -ne $params.MessageName ) {
    $changeCampaignName = $true
    $campaignName = $params.ListName
} else {
    $campaignName = [datetime]::Now.ToString("yyyy-MM-dd_HH:mm:ss")
}


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

$newSessionCreated = Get-TriggerDialogSession
$headers.add("Authorization", "Bearer $( Get-SecureToPlaintext -String $Script:sessionId )")

# Create JWT token for UI login
$jwtDecoded = Decode-JWT -token ( Get-SecureToPlaintext -String $Script:sessionId ) -secret ( Get-SecureToPlaintext $settings.authentication.authenticationSecret )


#-----------------------------------------------
# CHOOSE CUSTOMER ACCOUNT
#-----------------------------------------------

# Choose first customer account first
$customerId = $settings.customerId


#-----------------------------------------------
# DEFAULT TEXT
#-----------------------------------------------

$htmlTxt = "Keine Hinweise verfügbar."


#-----------------------------------------------
# WHAT TO DO?
#-----------------------------------------------

switch ( $message.campaignOperation ) {

    "CREATE" {


        #-----------------------------------------------
        # CREATE CAMPAIGN VIA REST
        #-----------------------------------------------

        $body = @{
            "campaignIdExt"= $processId #$campaignIdExt
            "campaignName"= $campaignName
            "customerId"= $customerId
        }
        $newCampaign = Invoke-TriggerDialog -method Post -customerId $customerId -path "longtermcampaigns" -headers $headers -body $body -returnRawObject

        Write-Log "Created a new campaign with id $( $newCampaign.id ) and name $( $newCampaign.campaignName )"

        <#
        id                    : 49029
        createdOn             : 2021-03-04T16:45:34.978Z
        changedOn             :
        version               : 1
        campaignType          : LONG_TERM
        campaignName          : 2021-03-04_17:45:34
        stateId               : 110
        product               :
        sendingReasonId       : 10
        actions               : {EDIT}
        requiredActions       : {DEFINE_PRODUCT, DEFINE_SENDING_REASON, ESTIMATE_CAMPAIGN, DEFINE_MAILING_TEMPLATE...}
        workflowType          : TRIGGER_COMPLETE
        hasDummyName          : False
        campaignIdExt         : 29e0a178-ea6b-47c7-aa72-6b8b5f806c4e
        variableDefVersion    :
        individualizationId   :
        printingProcessId     :
        deliveryProductId     :
        deliveryCheckSelected :
        #>

        #-----------------------------------------------
        # CREATE MAILING VIA REST
        #-----------------------------------------------

        $body = @{
            "campaignId"= $newCampaign.id
            "customerId"= $customerId
        }
        $newMailing = Invoke-TriggerDialog -method Post -customerId $customerId -path "mailings" -headers $headers -body $body -returnRawObject

        Write-Log "Created a new mailing with id $( $newMailing.id )"

        <#
        id                       : 43838
        createdOn                : 2021-03-04T16:45:35.558Z
        changedOn                :
        version                  : 1
        campaignId               : 49029
        variableDefVersion       : 0
        senderAddress            :
        mailingTemplateType      :
        addressMappingsConfirmed : True
        hasIndividualVariables   : False
        hasSelectedVariables     : False
        addressPageDefined       : False
        #>

        #-----------------------------------------------
        # CREATE FIELDS VIA REST
        #-----------------------------------------------

        $variableDefinitions = Create-VariableDefinitions -personalisation $testData.Personalisation
        
        # Create the variables onbject
        $body = @{
            "customerId" = $customerId
            "createVariableDefRequestRepList" = $variableDefinitions
        }
        $newVariables = Invoke-TriggerDialog -method Post -customerId $customerId -path  "mailings/$( $newMailing.id )/variabledefinitions" -Headers $headers -Body $body
        #$newVariables | Out-GridView
        Write-Log "Generated $( $newVariables.count ) fields in TriggerDialog"
        
        <#
        id createdOn                changedOn                version label             sortOrder dataType                     addressVariableId addressVariableMappingConfirmed selected
        -- ---------                ---------                ------- -----             --------- --------                     ----------------- ------------------------------- --------
        49872 2021-03-04T16:49:32.078Z 2021-03-04T16:49:32.409Z       2 Anrede                   10 @{id=10; label=Text}                         2                           False    False
        49867 2021-03-04T16:49:32.078Z                                1 Communication Key        20 @{id=10; label=Text}                                                     False    False
        49871 2021-03-04T16:49:32.078Z                                1 Geburtsdatum             30 @{id=10; label=Text}                                                     False    False
        49869 2021-03-04T16:49:32.078Z                                1 Kunden ID                40 @{id=10; label=Text}                                                     False    False
        49874 2021-03-04T16:49:32.078Z 2021-03-04T16:49:32.432Z       2 Nachname                 50 @{id=10; label=Text}                         5                           False    False
        49870 2021-03-04T16:49:32.078Z 2021-03-04T16:49:32.398Z       2 Ort                      60 @{id=10; label=Text}                         9                           False    False
        49868 2021-03-04T16:49:32.078Z 2021-03-04T16:49:32.385Z       2 PLZ                      70 @{id=80; label=Postleitzahl}                 8                           False    False
        49873 2021-03-04T16:49:32.078Z 2021-03-04T16:49:32.421Z       2 Strasse                  80 @{id=10; label=Text}                         6                           False    False
        49866 2021-03-04T16:49:32.078Z 2021-03-04T16:49:32.372Z       2 Vorname                  90 @{id=10; label=Text}                         4                           False    False
        #>

        #-----------------------------------------------
        # OUTPUT RESULT TO HTML
        #-----------------------------------------------
        
        $htmlTxt = "In TriggerDialog wurde eine Kampagne mit der ID '$( $newCampaign.id )' und der Mailing-ID '$( $newMailing.id )' erstellt.<br/>Dabei wurden $( $newVariables.count ) Variablen erstellt: $( ($newVariables.label -join ", ") )"


    }


    "EDIT" {
        
        #-----------------------------------------------
        # UPDATE CAMPAIGN VIA REST
        #-----------------------------------------------

        if ( $changeCampaignName ) {

            $body = @{
                "campaignName"= $campaignName
                "customerId"= $customerId
            }
            $newCampaign = Invoke-TriggerDialog -method Put -customerId $customerId -path "longtermcampaigns/$( $message.campaignId )" -headers $headers -body $body -returnRawObject

            Write-Log "Renamed an existing campaign with id $( $message.campaignId ) and name $( $campaignName )"

        }


        #-----------------------------------------------
        # CREATE FIELD DEFINITION OBJECT
        #-----------------------------------------------

        $newVariableDefinitions = Create-VariableDefinitions -personalisation $testData.Personalisation
        

        #-----------------------------------------------
        # LOAD EXISTING FIELDS
        #-----------------------------------------------

        $oldVariableDefinitions = Invoke-TriggerDialog -customerId $customerId -path "mailings/$( $message.mailingId )/variabledefinitions" -headers $headers
        

        #-----------------------------------------------
        # MATCH FIELDS TOGETHER
        #-----------------------------------------------

        # Compare columns
        # TODO [ ] paging needed for variables?
        $differences = Compare-Object -ReferenceObject $oldVariableDefinitions -DifferenceObject $newVariableDefinitions -IncludeEqual -Property label 
        $equalCols = $differences | where { $_.SideIndicator -eq "==" } 
        $addCols = $differences | where { $_.SideIndicator -eq "=>" }
        $removeCols = $differences | where { $_.SideIndicator -eq "<=" } 

        # Add it to existing columns
        $newVariableDefinitions | ForEach {
            $var = $_
            if ( $equalCols.label -contains $var.label ) {                
                $var | Add-Member -MemberType NoteProperty -Name "id" -Value $oldVariableDefinitions.Where({$_.label -eq $var.label}).id
            }
        }

        # Remove columns
        # TODO [ ] not needed at the moment


        #-----------------------------------------------
        # PUT NEW FIELDS TO TRIGGERDIALOG
        #-----------------------------------------------
        
        $body = @{
            "customerId" = $customerId
            "updateVariableDefRequestRepList" = $newVariableDefinitions
        }
        $updatedVariables = Invoke-TriggerDialog -method Put -customerId $customerId -path  "mailings/$( $message.mailingId )/variabledefinitions" -Headers $headers -Body $body

        #$updatedVariables | Out-GridView
        Write-Log "Updated $( $updatedVariables.count ) fields in TriggerDialog"
        

        #-----------------------------------------------
        # WRAP UP FOR THE CURRENT STATUS
        #-----------------------------------------------
        
        $htmlTxt = "In TriggerDialog wurde eine Kampagne mit der ID '$( $message.campaignId )' und der Mailing-ID '$( $message.mailingId )' angepasst.<br/>Dabei wurden $( $addCols.label.count ) neue Variablen erstellt: $( ($addCols.label -join ", ") )"
        if ( $changeCampaignName ) {
            $htmlTxt += "<br/>Die Kampagnen wurde von $( $message.campaignName ) in '$( $campaignName )' umbenannt."
        }

    }

    "UPLOAD" {

        $htmlTxt = "Alles ok. Kampagne bereit zum Starten."

    }

    "DELETE" {
                
        # Delete campaign
        Invoke-TriggerDialog -method Delete -customerId $customerId -path  "longtermcampaigns/$( $message.campaignId )" -Headers $headers
        Write-Log -message "The campaign with id '$( $message.campaignId )' was deleted" -severity ( [LogSeverity]::WARNING ) 
        $htmlTxt = "Die Kampagne mit ID '$( $message.campaignId )' wurde gelöscht."

    }

}


#-----------------------------------------------
# CREATE JWT AND AUTH URI
#-----------------------------------------------

# Figure out first and last name field names in preview window
$addressvariables = Invoke-TriggerDialog -Method Get -customerId $customerId -Path "mailings/addressvariables" -Headers $headers
$vornameSynonyms = $addressvariables.where({ $_.name -eq 'Vorname' }).synonyms -split ","
$vornameFieldname = ( $testData.Personalisation | Get-Member -MemberType NoteProperty | where { $_.Name -in $vornameSynonyms } ).Name
$nachnameSynonyms = $addressvariables.where({ $_.name -eq 'Nachname' }).synonyms -split ","
$nachnameFieldName = ( $testData.Personalisation | Get-Member -MemberType NoteProperty | where { $_.Name -in $nachnameSynonyms } ).Name

Write-Log -message "Creating a login url"

# Change default payload with email and real name
$payload = $settings.defaultPayload
$payload.email = $testData.email
$payload.username = $testData.email
$payload.firstname = testData.Personalisation.$vornameFieldname
$payload.lastname = testData.Personalisation.$nachnameFieldName

$jwt = Create-JwtToken -headers $settings.headers -payload $settings.defaultPayload -secret ( Get-SecureToPlaintext -String $settings.authentication.ssoTokenKey )

$uri = [uri]$settings.base 
$hostUri = $uri.AbsoluteUri -replace $uri.AbsolutePath
$authUri = "$( $hostUri )?partnersystem=$( $jwt )"
$authUri


#-----------------------------------------------
# SEND URL TO USER
#-----------------------------------------------

Write-Log -message "Sending an email with login details to $( $testData.Email )"

$splattedArguments = @{
    "to" = $testData.Email # Use the email of the current logged in user
    "subject" = "[TRIGGERDIALOG] Login" # TODO [ ] put this text into the settings
    "body" = "Hallo `nhier ist der Link zum Login: $( $authUri )" # TODO [ ] put this text into the settings
}
$emailSuccess = Send-Mail @splattedArguments # note the @ instead of $

Write-Log -message "Email was sent: $( $emailSuccess )"


################################################
#
# RETURN
#
################################################

# TODO [ ] implement subject and more of these things rather than using default values

# To jump directly to a campaign

$redirectHTML = Get-Content -Path ".\preview_template.html" -Encoding UTF8 -Raw

$redirectHTML = $redirectHTML -replace "#JWTLINK#",$authUri
$redirectHTML = $redirectHTML -replace "#NOTES#" ,$htmlTxt

$return = [Hashtable]@{
    "Type" = $settings.preview.Type
    "FromAddress"=$settings.preview.FromAddress
    "FromName"=$settings.preview.FromName
    "Html"= $redirectHTML #$c.Content
    "ReplyTo"=$settings.preview.ReplyTo
    "Subject"=$settings.preview.Subject
    "Text"="Lorem Ipsum"
}

return $return
