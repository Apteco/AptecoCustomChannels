###############################
#
# INPUT
#
###############################

<#

Send (params)
IntegrationParameters…
Username
Password

Receive (List)
Pairs of <id, name>


#>

###############################
#
# SETTINGS
#
###############################


###############################
#
# READ MESSAGES
#
###############################

$messages = @()

$messages += [pscustomobject]@{
    id = "123"
    name = "Message 1"
}

$messages += [pscustomobject]@{
    id = "456"
    name = "Message 2"
}

$messages += [pscustomobject]@{
    id = "789"
    name = "Message 3"
}




###############################
#
# RETURN MESSAGES
#
###############################


return $messages | select id, name
