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
        scriptPath = "D:\Scripts\TriggerDialog\v2"
        TestRecipient = '{"Email":"name@example.com","Sms":null,"Personalisation":{"Kunden ID":"Kunden ID","Anrede":"Anrede","Vorname":"Vorname","Nachname":"Nachname","Strasse":"Strasse","PLZ":"PLZ","Ort":"Ort","Communication Key":"02b4bddc-c115-48f1-b624-69f6f8318ad5"}}'
        MessageName = "41126 / 36146 / 2020-12-22_14:23:46 / Entwurf / EDIT"
        ListName = ""
        Password = "b"
        Username = "a"
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
$functionsSubfolder = "functions"
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$processId = [guid]::NewGuid()
$modulename = "TRPREVIEW"
$timestamp = [datetime]::Now

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
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

<#
# Load all exe files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
    
}

# Load dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
$libExecutables | ForEach {
    "Loading $( $_.FullName )"
    [Reflection.Assembly]::LoadFile($_.FullName) 
}
#>

Add-Type -AssemblyName System.Security


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"

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
        Write-Log -message "    $( $param ) = '$( $params[$param] )'"
    }
}


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

# Choose first customer account first
$customerId = $settings.customerId


#-----------------------------------------------
# WHAT TO DO?
#-----------------------------------------------

switch ( $message.campaignOperation ) {

    "CREATE" {

        #-----------------------------------------------
        # ASK FOR CAMPAIGN DATA
        #-----------------------------------------------

        #$campaignIdExt = Read-Host -Prompt "External ID for new campaign"
        #$campaignName = Read-Host -Prompt "Name for new campaign"
        # TODO [ ] read campaign name from other source

        #-----------------------------------------------
        # CREATE CAMPAIGN VIA REST
        #-----------------------------------------------

        $body = @{
            "campaignIdExt"= $processId #$campaignIdExt
            "campaignName"= [datetime]::Now.ToString("yyyy-MM-dd_HH:mm:ss")  #$campaignName
            "customerId"= $customerId
        }
        $bodyJson = $body | ConvertTo-Json
        $newCampaign = Invoke-RestMethod -Method POST -Uri "$( $settings.base )/longtermcampaigns" -Verbose -Headers $headers -ContentType $contentType -Body $bodyJson

        Write-Log "Created a new campaign with id $( $newCampaign.id ) and name $( $newCampaign.name )"

        #-----------------------------------------------
        # CREATE MAILING VIA REST
        #-----------------------------------------------

        $body = @{
            "campaignId"= $newCampaign.id
            "customerId"= $customerId
        }
        $bodyJson = $body | ConvertTo-Json
        $newMailing = Invoke-RestMethod -Method Post -Uri "$( $settings.base )/mailings" -Verbose -Headers $headers -ContentType $contentType -Body $bodyJson
        
        Write-Log "Created a new mailing with id $( $newMailing.id )"


        #-----------------------------------------------
        # CREATE FIELDS VIA REST
        #-----------------------------------------------

        $variableDefinitions = Create-VariableDefinitions -personalisation $testData.Personalisation
        
        # Create the variables onbject
        $body = @{
            "customerId" = $customerId
            "createVariableDefRequestRepList" = $variableDefinitions
        }
        $bodyJson = $body | ConvertTo-Json -Depth 10
        $newVariables = Invoke-RestMethod -Method Post -Uri "$( $settings.base )/mailings/$( $newMailing.id )/variabledefinitions" -Verbose -Headers $headers -ContentType $contentType -Body $bodyJson
        #$newVariables.elements | Out-GridView
        Write-Log "Generated $( $newVariables.elements.count ) fields in TriggerDialog"
        

        #-----------------------------------------------
        # OUTPUT RESULT TO HTML
        #-----------------------------------------------
        
        $htmlTxt = "Created a new campaign with $( $newCampaign.id ) and mailing id $( $newMailing.id ) and $( $newVariables.elements.count ) variables"


    }


    "EDIT" {
        
        #-----------------------------------------------
        # CREATE FIELD DEFINITION OBJECT
        #-----------------------------------------------

        $newVariableDefinitions = Create-VariableDefinitions -personalisation $testData.Personalisation
        

        #-----------------------------------------------
        # LOAD EXISTING FIELDS
        #-----------------------------------------------

        $oldVariableDefinitions = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/mailings/$( $message.mailingId )/variabledefinitions?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose

        
        #-----------------------------------------------
        # MATCH FIELDS TOGETHER
        #-----------------------------------------------

        # Compare columns
        # TODO [ ] paging needed for variables?
        $differences = Compare-Object -ReferenceObject $oldVariableDefinitions.elements -DifferenceObject $newVariableDefinitions -IncludeEqual -Property label 
        $equalCols = $differences | where { $_.SideIndicator -eq "==" } 
        $addCols = $differences | where { $_.SideIndicator -eq "=>" }
        $removeCols = $differences | where { $_.SideIndicator -eq "<=" } 

        # Add it to existing columns
        $newVariableDefinitions | ForEach {
            $var = $_
            if ( $equalCols.label -contains $var.label ) {                
                $var | Add-Member -MemberType NoteProperty -Name "id" -Value $oldVariableDefinitions.elements.Where({$_.label -eq $var.label}).id
            }
        }


        #-----------------------------------------------
        # PUT NEW FIELDS TO TRIGGERDIALOG
        #-----------------------------------------------
        
        $body = @{
            "customerId" = $customerId
            "updateVariableDefRequestRepList" = $newVariableDefinitions
        }
        $bodyJson = $body | ConvertTo-Json -Depth 10
        $updatedVariables = Invoke-RestMethod -Method Put -Uri "$( $settings.base )/mailings/$( $message.mailingId )/variabledefinitions" -Verbose -Headers $headers -ContentType $contentType -Body $bodyJson
        #$updatedVariables.elements | Out-GridView
        Write-Log "Updated $( $updatedVariables.elements.count ) fields in TriggerDialog"
        


        #-----------------------------------------------
        # UPLOAD TEST RECIPIENT
        #-----------------------------------------------

        # TODO [ ] Check upload of test recipient

        <#
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
        #>
        $htmlTxt = "Click the link here to edit the campaign"

    }

    "UPLOAD" {
        $htmlTxt = "All fine, publish and start the campaign in PeopleStage"
    }

    "DELETE" {
        
        # Delete mailing - not sure how this is called correctly
        # TODO [ ] check mailing method
        #Invoke-RestMethod -Method Delete -Uri "$( $settings.base )/mailings/36064?customerId=$( $customerId  )" -Verbose -Headers $headers -ContentType $contentType #-Body $bodyJson
        
        # Delete campaign
        Invoke-RestMethod -Method Delete -Uri "$( $settings.base )/longtermcampaigns/$( $message.campaignId )?customerId=$( $customerId  )" -Verbose -Headers $headers -ContentType $contentType #-Body $bodyJson
        $htmlTxt = "The campaign with $( $message.campaignId ) was just deleted"

    }

}


#-----------------------------------------------
# CREATE JWT AND AUTH URI
#-----------------------------------------------

Write-Log -message "Creating a login url"

$jwt = Create-JwtToken -headers $settings.headers -payload $settings.defaultPayload -secret ( Get-SecureToPlaintext -String $settings.authentication.ssoTokenKey )

$uri = [uri]$settings.base 
$hostUri = $uri.AbsoluteUri -replace $uri.AbsolutePath

# https://dm.deutschepost.de?partnersystem={YOUR-SIGNED-JWT}.
#$authUri = "https://dm-uat.deutschepost.de?partnersystem=$( $jwt )"
$authUri = "$( $hostUri )/campaign/editLongTermCampaign/34364?partnersystem=$( $jwt )"
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
#$emailSuccess = Send-Mail @splattedArguments # note the @ instead of $

Write-Log -message "Email was sent: $( $emailSuccess )"


#-----------------------------------------------
# OPEN IN DEFAULT BROWSER
#-----------------------------------------------

#$c = Invoke-WebRequest -Uri $authUri -UseBasicParsing

#Start-Process "$( $authUri )"

#[void](Read-Host 'Press Enter to continue…')


################################################
#
# RETURN
#
################################################

# TODO [ ] implement subject and more of these things rather than using default values

# To jump directly to a campaign
# https://dm-uat.deutschepost.de/campaign/editLongTermCampaign/34362

$redirectHTML = @"
<!DOCTYPE html>
<html>
   <head>
      <title>HTML Meta Tag</title>
        
   </head>
   <body>
        $( $mailing.ToString() )<br/>
        $( $mailing.campaignOperation )<p>&nbsp;</p>
        $( $htmlTxt )<p>&nbsp;</p>
        Sie erhalten eine E-Mail zum Login, hier ist die URL direkt: <a href="$( $authUri )" target="_new">$( $authUri )</a> 
   </body>
</html>
"@
#     <a href="$( $authUri )" target="_blank">$( $authUri )</a> 

<#
$redirectHTML = @"
<!DOCTYPE html>
<html>
   <head>
      <title>HTML Meta Tag</title>
      <meta http-equiv="refresh" content="0;URL=https://www.google.com/" />

        <script type="text/javascript">
            function Redirect() {
                window.location.href = "https://stackoverflow.com";
            }        
            document.write("Please wait you will be redirected in 3 seconds");
            setTimeout(Redirect, 3000);
        </script>
   </head>
   <body>
   
      <p>Redirecting to another URL</p>
   </body>
</html>
"@


<iframe src="$( $authUri )" title="W3Schools Free Online Web Tutorials" width="100%" height="300" style="border:none;"></iframe> 

#>

#window.location.replace('http://example.com/');

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
