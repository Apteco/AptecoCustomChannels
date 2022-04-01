
#-----------------------------------------------
# SOME MORE SETTINGS
#-----------------------------------------------

$rabatteSubfolder = "rabatte"
$mssqlConnectionString = $settings.connectionString

# the enviroment variable fills from the designer user defined variables
$rabattGUID = $processId.Guid -replace "-"


#-----------------------------------------------
# SQL FILES AND FOLDERS
#-----------------------------------------------

$campaignsSqlFilename = ".\sql\100_load_campaign_run.sql"
$customersSqlFilename = ".\sql\110_insert_customers.sql"
$rabattSqlFilename = ".\sql\120_insert_rabatt.sql"
$bulkDestination = "[customerbase].[PeopleStage].[tblCampaigns]"


#-----------------------------------------------
# DROPDOWN FOR THE MESSAGES
#-----------------------------------------------

$messagesDropdown = @(
    [pscustomobject]@{
        id = "0"
        name = "Rabatte zuordnen"
    }
    <#
    [pscustomobject]@{
        id = "1"
        name = "Rabatte löschen"
    }
    #>
)

#-----------------------------------------------
# DROPDOWN FOR THE LISTS, IF NEEDED
#-----------------------------------------------

<#
$messagesDropdown = @(
    [pscustomobject]@{
        id = "A"
        name = "Liste A"
    }
    
    [pscustomobject]@{
        id = "B"
        name = "Liste B"
    }

)
#>

#-----------------------------------------------
# CHECK IF ALL FOLDERS ARE EXISTING
#-----------------------------------------------

if ( !(Test-Path -Path $rabatteSubfolder) ) {
    New-Item -Path "$( $rabatteSubfolder )" -ItemType Directory
}

