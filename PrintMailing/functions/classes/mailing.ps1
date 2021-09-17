
<#
$m = [Mailing]@{mailingId=123;mailingName="MailingName"}
$m.toString()

Good hints here: https://xainey.github.io/2016/powershell-classes-and-concepts/

# Play around with different constructors
([Mailing]@{mailingId=123;mailingName="abc"}).toString()
([Mailing]::new("123 / abc")).toString()


#>
class Mailing {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [int]$mailingId
    [String]$mailingName = ""
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

    Mailing () {

        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

    } # empty default constructor needed to support hashtable constructor
    
    Mailing ( [int]$mailingId, [String]$mailingName ) {

        $this.mailingId = $mailingId
        $this.mailingName = $mailingName

        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

    }

    Mailing ( [String]$mailingString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

        # Use the 2 in the split as a parameter so it only breaks the string on the first occurence
        $stringParts = $mailingString -split $this.nameConcatChar.trim(),2,"simplematch"
        $this.mailingId = $stringParts[0].trim()
        $this.mailingName = $stringParts[1].trim()
        
    }


    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [String] toString()
    {
        return $this.mailingId, $this.mailingName -join $this.nameConcatChar
    }    

}







<#
Inherit the mailing class and add more details
To show constructors of a class just use
[TriggerDialogMailing]::New
E.g. this class could be created with 
[TriggerDialogMailing]::New(123,"MailingName",456,"CampaignName")
or via Hashtable and named arguments
$tg = [TriggerDialogMailing]@{mailingId=123;mailingName="MailingName";campaignId=456;campaignName="CampaignName";campaignState="aktiv"}
$tg.toString()
Good descriptions here: https://www.sapien.com/blog/2015/10/26/creating-objects-in-windows-powershell/
#>
class TriggerDialogMailing : Mailing {

    # Properties
    [int]$campaignId
    [String]$campaignName = ""
    [String]$campaignState = ""
    [String]$campaignOperation = ""

    # Constructors
    TriggerDialogMailing () {

        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

    } # empty default constructor needed to support hashtable constructor

    # Just to explain -> this constructor accepts 4 input arguments, calls the base constructor with 2 of those arguments and fills the class instance with own properties
    TriggerDialogMailing ( [int]$campaignId, [String]$campaignName, [String]$campaignState, [String]$campaignOperation, [int]$mailingId, [String]$mailingName ) : base( $mailingId, $mailingName) {
        $this.campaignId = $campaignId
        $this.campaignName = $campaignName
        $this.campaignState = $campaignState
        $this.campaignOperation = $campaignOperation
    }

    TriggerDialogMailing ( [String]$mailingString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

        $stringParts = $mailingString -split $this.nameConcatChar.trim(),5,"simplematch"
        $this.campaignId = $stringParts[0].trim()
        $this.mailingId = $stringParts[1].trim()
        $this.campaignName = $stringParts[2].trim()
        $this.campaignState = $stringParts[3].trim()
        $this.campaignOperation = $stringParts[4].trim()
        
    }

    # Methods
    [String] toString()
    {
        return $this.campaignId, $this.mailingId, $this.campaignName, $this.campaignState, $this.campaignOperation -join $( $this.nameConcatChar )
    }    

    

}


[TriggerDialogMailing]::new("0 | 0 | New Campaign + Mailing | New | CREATE")
#[TriggerDialogMailing]::new('0 / 0 / New Campaign + Mailing / New / CREATE')