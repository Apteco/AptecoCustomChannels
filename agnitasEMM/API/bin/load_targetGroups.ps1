
# Load data from Agnitas EMM
#$targetgroupsEmm = Invoke-Agnitas -method "ListTargetgroups" #-wsse $wsse #-verboseCall


# Load the data from Agnitas EMM
try {

    <#
        https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Mailinglist-getMailinglist
    #>
    $restParams = @{
        Method = "Get"
        Uri = "$( $apiRoot )/target"
        Headers = $header
        Verbose = $true
        ContentType = $contentType
    }
    Check-Proxy -invokeParams $restParams
    $targetgroupsEmm = Invoke-RestMethod @restParams
    #$invoke = $invoke.mailinglist_id

} catch {

    Write-Log -message "StatusCode: $( $_.Exception.Response.StatusCode.value__ )" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "StatusDescription: $( $_.Exception.Response.StatusDescription )" -severity ( [LogSeverity]::ERROR )

    throw $_.Exception

}

# Transform the target groups into an array of targetgroup objects
$targetGroups = [System.Collections.ArrayList]@()
$targetgroupsEmm | ForEach {
    [void]$targetGroups.Add([TargetGroup]@{
        targetGroupId=$_.target_id
        targetGroupName=$_.name
    })
}

# Filter the target groups
$aptecoTargetgroups = @( $targetGroups | where { $_.targetGroupName -like "$( $settings.upload.targetGroupPrefix )*" } )
