
#-----------------------------------------------
# CREATE A SUBCLASS FOR LISTS
#-----------------------------------------------

<#
$m = [List]@{listId=123;listName="ListName"}
$m.toString()

Good hints here: https://xainey.github.io/2016/powershell-classes-and-concepts/

# Play around with different constructors
([List]@{listId=123;listName="abc"}).toString()
([List]::new("123 / abc")).toString()
[List]::new("Hello / World / Demo") creates "Hello" for listId, "World / Demo" for listName
([List]::new("Hello / World / Demo")).getConcatChar() returns the concat character
#>
class List {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [String]$listId
    [String]$listName = ""
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

    List () {} # empty default constructor needed to support hashtable constructor
    
    List ( [String]$listId, [String]$listName ) {

        $this.listId = $listId
        $this.listName = $listName

        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

    }

    List ( [String]$listString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

        # Use the 2 in the split as a parameter so it only breaks the string on the first occurence
        $stringParts = $listString -split $this.nameConcatChar.trim(),2
        $this.listId = $stringParts[0].trim()
        $this.listName = $stringParts[1].trim()
        
    }

    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [String] toString()
    {
        return $this.listId, $this.listName -join $this.nameConcatChar
    }

    [String] getConcatChar()
    {
        return $this.nameConcatChar
    }    

}
