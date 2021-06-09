#-----------------------------------------------
# CREATE A SUBCLASS FOR WORKFLOWS
#-----------------------------------------------

<#
$m = [FlxWorkflow]@{workflowId=123;workflowName="MailingName"}
$m.toString()
Good hints here: https://xainey.github.io/2016/powershell-classes-and-concepts/
# Play around with different constructors
([FlxWorkflow]@{workflowId=123;workflowName="abc"}).toString()
([FlxWorkflow]::new("123 / abc")).toString()
#>
class FlxWorkflow {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [int]$workflowId
    [String]$workflowName = ""
    [int]$workflowSource = ""
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

    # empty default constructor needed to support hashtable constructor
    FlxWorkflow () {

        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

    } 
    
    FlxWorkflow ( [String]$workflowId, [String]$workflowSource ,[String]$workflowName ) {

        $this.workflowId = $workflowId
        $this.workflowSource = $workflowSource
        $this.workflowName = $workflowName

        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }
        
    }

    FlxWorkflow ( [String]$workflowId, [String]$workflowString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }
        
        $this.workflowId = $workflowId

        $stringParts = $workflowString -split [regex]::Escape($this.nameConcatChar.trim()),2
        $this.workflowSource = $stringParts[0].trim()
        $this.workflowName = $stringParts[1].trim()
        
    }

    FlxWorkflow ( [String]$workflowString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

        $stringParts = $workflowString -split [regex]::Escape($this.nameConcatChar.trim()),3
        $this.workflowId = $stringParts[0].trim()
        $this.workflowSource = $stringParts[1].trim()
        $this.workflowName = $stringParts[2].trim()
        
    }

    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [String] toString()
    {
        return $this.workflowId, $this.workflowSource, $this.workflowName -join $this.nameConcatChar
    }    

}