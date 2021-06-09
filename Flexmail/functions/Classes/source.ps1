#-----------------------------------------------
# CREATE A SUBCLASS FOR SOURCES
#-----------------------------------------------

<#
$m = [Source]@{sourceId=123;sourceName="MailingName"}
$m.toString()
Good hints here: https://xainey.github.io/2016/powershell-classes-and-concepts/
# Play around with different constructors
([Source]@{sourceId=123;sourceName="abc"}).toString()
([Source]::new("123 / abc")).toString()
#>
class Source {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [String]$sourceId
    [String]$sourceName = ""
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
    Source () {
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

    } 
    
    Source ( [String]$sourceId, [String]$sourceName ) {

        $this.sourceId = $sourceId
        $this.sourceName = $sourceName

        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

    }

    Source ( [String]$sourceString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

        # espace when using pipe character as split
        # the ,2 means only 2 parts, so it will only be splitted at the first occurence
        $stringParts = $sourceString -split [regex]::Escape($this.nameConcatChar.trim()),2
        $this.sourceId = $stringParts[0].trim()
        $this.sourceName = $stringParts[1].trim()
        
    }

    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [String] toString()
    {
        return $this.sourceId, $this.sourceName -join $this.nameConcatChar
    }    

}