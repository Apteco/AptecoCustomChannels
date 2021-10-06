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

$debug = $true


#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{

        # Integration parameters
        scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\agnitasEMM"
        mode= "tags"

        # PeopleStage parameters
        TransactionType = "Replace"
        Password = "b"
        MessageName = ""
        EmailFieldName = "email"
        SmsFieldName = ""
        Path = "d:\faststats\Publish\Handel\system\Deliveries\PowerShell_34362  30449  Kampagne A  Aktiv  UPLOAD_52af38bc-9af1-428e-8f1d-6988f3460f38.txt"
        ReplyToEmail = "" 
        Username = "a"
        ReplyToSMS = ""
        UrnFieldName = "Kunden ID"
        ListName = "7883836 | +AptecoOrbit"
        CommunicationKeyFieldName = "Communication Key"

        # Parameters from previous script

    }
}


################################################
#
# NOTES
#
################################################

<#

https://support.klicktipp.com/article/388-rest-application-programming-interface-api

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
# SETTINGS AND STARTUP
#
################################################

# General settings
$modulename = "KTUPLOAD"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"

# Do the preparation
. ".\bin\preparation.ps1"


################################################
#
# PROCESS
#
################################################

#$settings.upload.klickTippIdField
exit 0
switch ( $params.mode ) {

    #-----------------------------------------------
    # ADD/REMOVE TAG
    #-----------------------------------------------


    "tags" {

        # Split the listname string
        $listnameSplit = $params.ListName -split $settings.nameConcatChar,2,"SimpleMatch"
        $tagId = $listnameSplit[0]
        $tagName = $listnameSplit[1]

        # Load existing tags
        $restParams = $defaultRestParams + @{
            "Method" = "Get"
            "Uri" = "$( $settings.base )/tag.json"
        }
        $tags = Invoke-RestMethod @restParams

        # Transform tags
        $tagList = [System.Collections.ArrayList]@()
        $tags.psobject.members | where { $_.MemberType -eq "NoteProperty" } | ForEach {
            $tag = $_
            [void]$tagList.add([PSCustomObject]@{
                "id" = $tag.Name
                "name" = $tag.Value
            })
        }
        
        # Check if tag is still valid
        if ( $taglist.id -contains $tagid ) {
        
            # TODO  [ ] create the loops here
            Switch ( $tagName.Substring(0,1) ) {

                "+" {

                    $restParams = $defaultRestParams + @{
                        "Method" = "Post"
                        "Uri" = "$( $settings.base )/subscriber/tag.json"
                        "Body" = @{
                            "email" = ""
                            "tagids" = $tagId
                        } | ConvertTo-Json -Depth 99
                    }
                    $addTag = Invoke-RestMethod @restParams        
            
                }

                "-" {

                    $restParams = $defaultRestParams + @{
                        "Method" = "Post"
                        "Uri" = "$( $settings.base )/subscriber/untag.json"
                        "Body" = @{
                            "email" = ""
                            "tagid" = $tagId
                        } | ConvertTo-Json -Depth 99
                    }
                    $removeTag = Invoke-RestMethod @restParams

                }

            }

        } else {

            Write-Log -message "Tag '$( $params.ListName )' does not exist" -severity ( [Logseverity]::WARNING )
            throw [System.IO.InvalidDataException] "Tag '$( $params.ListName )' does not exist"
        
        }

        exit 0
    }

    #-----------------------------------------------
    # SUBSCRIBE / UNSUBSCRIBE
    #-----------------------------------------------   

    # Setup if setting is not present or not tags
    default {
        
        # Split the listname string
        $listnameSplit = $params.ListName -split $settings.nameConcatChar,2,"SimpleMatch"
        $process = $listnameSplit[0]


        $list = $modeList

        # Load fields
        $restParams = $defaultRestParams + @{
            "Method" = "Get"
            "Uri" = "$( $settings.base )/field.json"
        }
        $fieldsRaw = Invoke-RestMethod @restParams

        # Bring fields into right order
        $fields = [ordered]@{}
        $fieldsRaw.psobject.Properties | ForEach {
            $field = $_
            $fields.Add($field.name,$field.value)
        }

        switch ( $process ) {

            # subscribe
            "10" {


                $restParams = $defaultRestParams + @{
                    "Method" = "Post"
                    "Uri" = "$( $settings.base )/subscriber.json"
                    "Body" = @{
                        email = "florian.von.bracht@apteco.de"
                        #smsnumber = ""
                        #listid = 0
                        #tagid = 0
                        fields = @{
                            "fieldFirstName" = "Florian"
                            "fieldLastName" = "vön Bracht"
                            "fieldZip" = "52080"
                        }
                    } | ConvertTo-Json -Depth 99
                }
                $subscribedUser = Invoke-RestMethod @restParams

                # TODO [ ] Write this user result directly to database

            }

            # update
            "20" {

                $restParams = $defaultRestParams + @{
                    "Method" = "Put"
                    "Uri" = "$( $settings.base )/subscriber/$( $subscriberId ).json"
                    "Body" = @{
                        fields = @{
                            "fieldFirstName" = "Florian"
                            "fieldLastName" = "vön Bracht"
                            "fieldZip" = "52080"
                        }
                        #newemail = ""
                        #newsmsnumber = ""
                    } | ConvertTo-Json -Depth 99
                }
                $updatedUser = Invoke-RestMethod @restParams

            }

            # unsubscribe
            "30" {

                $restParams = $defaultRestParams + @{
                    "Method" = "Post"
                    "Uri" = "$( $settings.base )/subscriber/unsubscribe.json"
                    "Body" = @{
                        email = "florian.von.bracht@apteco.de"
                    } | ConvertTo-Json -Depth 99
                }
                $unsubscribedUser = Invoke-RestMethod @restParams

            }

            # delete
            "40" {

                $restParams = $defaultRestParams + @{
                    "Method" = "Delete"
                    "Uri" = "$( $settings.base )/subscriber/$( $subscriberId ).json"
                }
                $deletedUser = Invoke-RestMethod @restParams

            }

        }




    }

}

# Do the end stuff
. ".\bin\end.ps1"

exit 0

################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

$queued = $dataCsv.Count

If ( $queued -eq 0 ) {
    Write-Host "Throwing Exception because of 0 records"
    throw [System.IO.InvalidDataException] "No records were successfully uploaded"  
}

# return object
$return = [Hashtable]@{

    # Mandatory return values
    "Recipients"        = $queued 
    "TransactionId"     = $result.correlationId

    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider"    = $moduleName
    "ProcessId"         = $processId

    # Some more information for the broadcasts script
    #"Path"              = $params.Path
    #"UrnFieldName"      = $params.UrnFieldName
    #"CorrelationId"     = $result.correlationId

    # More information about the different status of the import
    #"RecipientsIgnored" = $ignored
    #"RecipientsQueued" = $queued

}

# return the results
$return