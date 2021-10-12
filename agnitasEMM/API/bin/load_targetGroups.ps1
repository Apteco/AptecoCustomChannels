# Load data from Agnitas EMM
$targetgroupsEmm = Invoke-Agnitas -method "ListTargetgroups" #-wsse $wsse #-verboseCall

# Transform the target groups into an array of targetgroup objects
$targetGroups = [System.Collections.ArrayList]@()
$targetgroupsEmm.item | ForEach {
    [void]$targetGroups.Add([TargetGroup]@{
        targetGroupId=$_.id
        targetGroupName=$_.name
    })
}