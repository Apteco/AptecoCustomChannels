<#
TODO [ ] Find out where to activate the global tracking
#>


$trackedOnly = $true

#-----------------------------------------------
# Opens https://apidocs.inxmail.com/xpro/rest/v1/#retrieve-web-beacon-hits-collection
#-----------------------------------------------

# /web-beacon-hits{?sendingId,mailingIds,listIds,trackedOnly,embedded,startDate,endDate,recipientAttributes}
# "$( $apiRoot )$( $object )?afterId=$( $i )&pageSize=$( $p )&mailingStates=APPROVED"
$opensRes = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )web-beacon-hits?trackedOnly=$( $trackedOnly )" -Header $header -ContentType "application/hal+json" -Verbose
$opens = $opensRes._embedded."inx:web-beacon-hits"
$opens | ft

#-----------------------------------------------
# Clicks https://apidocs.inxmail.com/xpro/rest/v1/#retrieve-click-collection
#-----------------------------------------------

$clicksRes = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )clicks?embedded=inx:recipient&recipientAttributes=firstName,lastName&trackedOnly=$( $trackedOnly )" -Header $header -ContentType "application/hal+json" -Verbose
$clicks = $clicksRes._embedded."inx:clicks"
$clicks | ft
# TODO [ ] Read out links https://apidocs.inxmail.com/xpro/rest/v1/#_retrieve_mailing_links_collection or https://apidocs.inxmail.com/xpro/rest/v1/#retrieve-all-links

#-----------------------------------------------
# Bounces https://apidocs.inxmail.com/xpro/rest/v1/#retrieve-bounce-collection
#-----------------------------------------------

$bouncesRes = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )clicks?embedded=inx:recipient&recipientAttributes=firstName,lastName&trackedOnly=$( $trackedOnly )" -Header $header -ContentType "application/hal+json" -Verbose
#$bounces = $bouncesRes._embedded."inx:bounces"
#$bounces | ft

#-----------------------------------------------
# Blacklist https://apidocs.inxmail.com/xpro/rest/v1/#_retrieve_blacklist_entry_collection
#-----------------------------------------------


#-----------------------------------------------
# Unsubscribes https://apidocs.inxmail.com/xpro/rest/v1/#retrieve-unsubscription-events
#-----------------------------------------------

# for mailing specific unsubscribes see the sending protocol stuff

#-----------------------------------------------
# Sends -> the sendings should have some buffer in the time frame that is being requested as described here: https://apidocs.inxmail.com/xpro/rest/v1/#retrieve-all-sendings
#-----------------------------------------------

$sendingsRes = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )sendings" -Header $header -ContentType "application/hal+json" -Verbose
$sendings = $sendingsRes._embedded."inx:sendings"
$sendings

#https://apidocs.inxmail.com/xpro/rest/v1/#retrieve-sending-protocol-collection

$protocol = [System.Collections.ArrayList]@()
<#
Possible states
NOT_SENT, SENT, RECIPIENT_NOT_FOUND, ERROR, ADDRESS_REJECTED, HARDBOUNCE, SOFTBOUNCE, UNKNOWNBOUNCE, SPAMBOUNCE, MUST_ATTRIBUTE, NO_MAIL
#>
$sendings | ForEach {

    $sending = $_

    $protocolRes = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )/sendings/$( $sending.id )/protocol" -Header $header -ContentType "application/hal+json" -Verbose
    $protocol.AddRange( @( $protocolRes._embedded."inx:protocol-entries" | select @{name="sendingId";expression={ $sending.id }}, * ) )

}



