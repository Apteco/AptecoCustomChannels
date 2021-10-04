
<#
$m = [TargetGroup]@{targetGroupId=123;targetGroupName="MailingName"}
$m.toString()

Good hints here: https://xainey.github.io/2016/powershell-classes-and-concepts/

# Play around with different constructors
([TargetGroup]@{targetGroupId=123;targetGroupName="abc"}).toString()
([TargetGroup]::new("123 / abc")).toString()


#>
class TargetGroup {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [int]$targetGroupId
    [String]$targetGroupName = ""
    hidden [String]$nameConcatChar = " / "


    #-----------------------------------------------
    # CONSTRUCTORS
    #-----------------------------------------------

    <#
    Notes from: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_object_creation?view=powershell-7
    You can create an object from a hash table of properties and property values.

    The syntax is as follows:

    [<class-name>]@{
    <property-name>=<property-value>
    <property-name>=<property-value>
    }

    This method works only for classes that have a parameterless constructor. The object properties must be public and settable.

    #>

    TargetGroup () {

        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

    } # empty default constructor needed to support hashtable constructor
    
    TargetGroup ( [int]$targetGroupId, [String]$targetGroupName ) {

        $this.targetGroupId = $targetGroupId
        $this.targetGroupName = $targetGroupName

        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

    }

    TargetGroup ( [String]$targetGroupString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

        # Use the 2 in the split as a parameter so it only breaks the string on the first occurence
        $stringParts = $targetGroupString -split $this.nameConcatChar.trim(),2,"simplematch"
        $this.targetGroupId = $stringParts[0].trim()
        $this.targetGroupName = $stringParts[1].trim()
        
    }


    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [String] toString()
    {
        return $this.targetGroupId, $this.targetGroupName -join $this.nameConcatChar
    }    

}


