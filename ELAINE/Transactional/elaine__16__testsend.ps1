

################################################
#
# NOTES
#
################################################

<#

THIS IS ONLY A DRAFT AND NOT TESTED YET

#>


#-----------------------------------------------
# TEST SEND
#-----------------------------------------------
<#
Upload an array in the api call and send email directly
#>

$function = "api_mailingTestsend"
$jsonInput = @(
    ""      # int $nl_id
    ""      # int $ev_id
) 

$testsend = Invoke-ELAINE -function "api_mailingTestsend" -method Post -parameters $jsonInput
