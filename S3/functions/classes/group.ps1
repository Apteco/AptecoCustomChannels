
#-----------------------------------------------
# CREATE A SUBCLASS FOR AUTOMATIONS
#-----------------------------------------------

<#
$m = [Mailing]@{mailingId=123;mailingName="MailingName"}
$m.toString()

Good hints here: https://xainey.github.io/2016/powershell-classes-and-concepts/

# Play around with different constructors
([Mailing]@{mailingId=123;mailingName="abc"}).toString()
([Mailing]::new("123 / abc")).toString()


#>
class Group {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [String]$groupId
    [String]$groupName = ""
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

    Group () {} # empty default constructor needed to support hashtable constructor
    
    Group ( [String]$groupId, [String]$groupName ) {

        $this.groupId = $groupId
        $this.mailingName = $groupName

        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

    }

    Group ( [String]$groupString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

        $stringParts = $groupString -split $this.nameConcatChar.trim(),2
        $this.groupId = $stringParts[0].trim()
        $this.groupName = $stringParts[1].trim()
        
    }

    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [String] toString()
    {
        return $this.groupId, $this.groupName -join $this.nameConcatChar
    }    

}

