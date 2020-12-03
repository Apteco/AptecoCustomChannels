
#-----------------------------------------------
# CREATE A SUBCLASS FOR AUTOMATIONS
#-----------------------------------------------

# TODO [ ] put the subclasses in other source files


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

    [String]$mailingId
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

    Mailing () {} # empty default constructor needed to support hashtable constructor
    
    Mailing ( [String]$mailingId, [String]$mailingName ) {

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

        $stringParts = $mailingString -split $this.nameConcatChar.trim() 
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
[OptilyzAutomation]::New
E.g. this class could be created with 
[OptilyzAutomation]::New("abc","MailingName")
or via Hashtable and named arguments
$tg = [OptilyzAutomation]@{mailingId="abc";mailingName="MailingName"}
$tg.toString()
Good descriptions here: https://www.sapien.com/blog/2015/10/26/creating-objects-in-windows-powershell/
#>
class OptilyzAutomation : Mailing {

    # Properties
    [String]$automationId
    [String]$automationName = ""
    #[String]$campaignState = ""

    # Constructors
    OptilyzAutomation () {} # empty default constructor needed to support hashtable constructor
    # Just to explain -> this constructor accepts 4 input arguments, calls the base constructor with 2 of those arguments and fills the class instance with own properties
    OptilyzAutomation ( [String]$mailingId, [String]$mailingName) : base( $mailingId, $mailingName) {
        $this.automationId = $mailingId
        $this.automationName = $mailingName
        #$this.campaignState = $campaignState
    }

    OptilyzAutomation ( [String]$automationString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

        $stringParts = $automationString -split $this.nameConcatChar.trim() 
        $this.automationId = $stringParts[0].trim()
        #$this.mailingId = $stringParts[1].trim()
        $this.automationName = $stringParts[1].trim()
        #$this.campaignState = $stringParts[3].trim()
        
    }

    # Methods
    [String] toString()
    {
        return $this.automationId, $this.automationName -join $( $this.nameConcatChar )
    }    

    

}

