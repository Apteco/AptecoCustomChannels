
################################################
#
# GENERIC CLASSES AND ENUMS
#
################################################





################################################
#
# INHERITED CLASSES AND ENUMS
#
################################################

class MotifAlternative {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [int] $id
    [string] $name

    hidden [String] $nameConcatChar = " / "
    hidden [bool] $defaultUseWatermark = $false

    [Motif] $motif # parent element
    [PSCustomObject]$raw        # the raw source object for this one 
    

    #-----------------------------------------------
    # PUBLIC CONSTRUCTORS
    #-----------------------------------------------

    # empty default constructor needed to support hashtable constructor
    MotifAlternative () {

        $this.init()

    } 

    MotifAlternative ( [String]$inputString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        $this.init($inputString)

    }


    #-----------------------------------------------
    # HIDDEN CONSTRUCTORS - CHAINING
    #-----------------------------------------------


    [void] init () {
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }

    }

    # Used for a minimal input
    [void] init ([String]$inputString ) {

        $this.init()

        $stringParts = $inputString -split [regex]::Escape($this.nameConcatChar.trim()),3
        $this.motif = [Motif]@{
            id = $stringParts[0].trim()
        }
        $this.id = $stringParts[1].trim()
        $this.name = $stringParts[2].trim()

    }

    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [String] toString() {
        $desc = "$( $this.motif.name ) - $( $this.id ) - $( $this.name )"
        return $this.motif.id, $this.id, $desc -join $this.nameConcatChar
    }

    # TODO [ ] think about returning values, e.g. saving local or inline image
    [String]createSinglePicture([array]$lines, [int]$width, [int]$height, [bool]$useWatermark, [String]$outputFile, [bool]$returnBase64) {

        # Get alphapictures object
        $alpha = $this.motif.alphaPictures

        # Translate lines into object
        # TODO  [ ] check if there are more lines or characters than available
        $textLines = [PSCustomObject]@{}
        $maxLines = ( $this.raw.lines | Get-Member -MemberType NoteProperty | select name -Last 1 ).Name
        $i = 0
        $this.raw.lines | Get-Member -MemberType NoteProperty | ForEach {
            $lineNumber = $_.Name
            $maxCharsLine = $this.raw.lines.$lineNumber.length
            $lineText = $lines[$i++]
            $textLines | Add-Member -MemberType NoteProperty -Name $lineNumber -Value $lineText
        }

        # Create body for the picture generation
        $body = [Ordered]@{
            MotifId = $this.motif.id    # Id of the motif
            AlternativeId = $this.id    # Alternative Id
            Lines = $textLines          # The text for the lines
            Dimensions = @{             # Pixel dimensions
                "w" = $width
                "h" = $height
            }
            <#
            "SourceRect" = @{ # Optional: SourceRect is for retrieving a certain cut-out of the original image
                "x1" = 1532
                "y1" = 1353
                "x2" = 3801
                "y2" = 2195
            }
            #>
            Watermark = $useWatermark   # Optional: set to true if image should be watermarked
        }

        # Call AlphaPictures
        $params = $alpha.defaultParams + @{
            uri = "$( $alpha.baseUrl)Image"
            method = "Post"
            body = ConvertTo-Json -InputObject $body -Depth 8
            outFile = $outputFile # TODO [ ] make this more parametrised and also load picture inline for preview window
            returnBase64 = $returnBase64
        }
        $res = Invoke-AlphaPictures @params

        return $res
        
    }

    [String]createSinglePicture([array]$lines, [int]$width, [int]$height, [bool]$returnBase64) {

        $useWatermark = $this.defaultUseWatermark
        $res = $this.createSinglePicture($lines, $width, $height, $useWatermark, "", $returnBase64)
        return $res

    }

    [String]createSinglePicture([array]$lines, [int]$width, [int]$height, [String]$outputFile) {

        $useWatermark = $this.defaultUseWatermark
        $res = $this.createSinglePicture($lines, $width, $height, $useWatermark, $outputFile, $false)
        return $res

    }

    [String]createSinglePicture([array]$lines, [int]$width, [int]$height) {

        $res = $this.createSinglePicture($lines, $width, $height, "")
        return $res

    }

    [String]createSinglePicture([array]$lines, [String]$outputFile) {

        $size = $this.raw.original_rect -split ", ",4
        $width = $size[2]
        $height = $size[3]

        $res = $this.createSinglePicture($lines, $width, $height, $outputFile)
        return $res

    }

    [String]createSinglePicture([array]$lines, [bool]$returnBase64) {

        $size = $this.raw.original_rect -split ", ",4
        $width = $size[2]
        $height = $size[3]

        $res = $this.createSinglePicture($lines, $width, $height, $returnBase64)
        return $res

    }

    [String]createSinglePicture([array]$lines) {

        $res = $this.createSinglePicture($lines, "")
        return $res

    }

}

class Motif {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    [int] $id
    [string] $name
    [DateTime]$created
    [DateTime]$updated
    [System.Collections.ArrayList]$alternatives
    
    hidden [String] $nameConcatChar = " / "

    hidden [AlphaPictures]$alphaPictures    # parent class
    [PSCustomObject]$raw        # the raw source object for this one 


    #-----------------------------------------------
    # PUBLIC CONSTRUCTORS
    #-----------------------------------------------

    # empty default constructor needed to support hashtable constructor
    Motif () {

        $this.init()

    } 
    

    Motif ( [String]$inputString ) {        
        
        # If we have a nameconcat char in the settings variable, just use it
        $this.init($inputString)

    }

    #-----------------------------------------------
    # HIDDEN CONSTRUCTORS - CHAINING
    #-----------------------------------------------


    [void] init () {
        
        # If we have a nameconcat char in the settings variable, just use it
        if ( $script:settings.nameConcatChar ) {
            $this.nameConcatChar = $script:settings.nameConcatChar
        }
<#
        if ( $this.raw.alternatives ) {
            $this.raw.alternatives | ForEach {
                $alternative = $_
                [void]$this.$alternatives.add(
                    [MotifAlternative]@{
                        id = $alternative.id
                        name = $alternative.name
                        motif = $this
                        raw = $alternative
                    }
                )
            }
        }
#>
    }

    # Used for a minimal input
    [void] init ([String]$inputString ) {

        $this.init()

        $stringParts = $inputString -split [regex]::Escape($this.nameConcatChar.trim()),2
        $this.id = $stringParts[0].trim()
        $this.name = $stringParts[1].trim()

    }


    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [void] setAlternatives($alternatives) {
        $this.alternatives = [System.Collections.ArrayList]@()
        $this.addAlternatives($alternatives)
    }

    [void] addAlternatives($alternatives) {
        $alternatives | ForEach {
            $alternative = $_            
            [void]$this.alternatives.add(
                [MotifAlternative]@{
                    id = $alternative.alternative_id
                    name = $alternative.name
                    motif = $this
                    raw = $alternative
                }
            )
        }
    }

    [String] toString() {
        return $this.id, $this.name -join $this.nameConcatChar
    }



}





################################################
#
# MAIN CLASS
#
################################################


class AlphaPictures {

    #-----------------------------------------------
    # PROPERTIES (can be public by default, static or hidden)
    #-----------------------------------------------

    hidden [pscredential]$cred                 # holds the username and secret
    hidden [int]$waitSeconds = 10 
    [String]$baseUrl = "https://v4.alphapicture.com/"

    [String]$providerName = "alphapictures"

    [PSCustomObject]$defaultParams


    #-----------------------------------------------
    # PUBLIC CONSTRUCTORS
    #-----------------------------------------------

    AlphaPictures() {
        $this.init()
    }

    AlphaPictures ( [String]$username, [String]$secret ) {        
        $this.init( $username, $secret )
    }

    AlphaPictures ( [String]$username, [String]$secret, [String]$baseUrl ) {
        $this.init( $username, $secret, $baseUrl)
    }

    AlphaPictures ( [pscredential]$cred ) {
        $this.init( $cred )
    }

    AlphaPictures ( [pscredential]$cred, [String]$baseUrl ) {
        $this.init( $cred, $baseUrl )
    }


    #-----------------------------------------------
    # HIDDEN CONSTRUCTORS - CHAINING
    #-----------------------------------------------

    hidden [void] init () {

        $this.defaultParams = @{
            cred = $this.cred
        }

        if ( $script:settings.download.waitSecondsLoop ) {
            $this.waitSeconds = $script:settings.download.waitSecondsLoop
        }

    }

    hidden [void] init ( [String]$username, [String]$secret ) {
        $stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $secret ) -AsPlainText -Force
        $this.cred = [pscredential]::new( $username, $stringSecure )
        $this.init()
    }

    hidden [void] init ( [String]$username, [String]$secret, [String]$baseUrl ) {
        $this.baseUrl = $baseUrl
        $this.init( $username, $secret )
    }

    hidden [void] init ( [pscredential]$cred ) {
        $this.cred = $cred
        $this.init()
    }

    hidden [void] init ( [pscredential]$cred, [String]$baseUrl ) {
        $this.baseUrl = $baseUrl
        $this.init( $cred )
    }


    #-----------------------------------------------
    # METHODS
    #-----------------------------------------------

    [PSCustomObject] getMotifs () {

        # Call AlphaPictures
        $params = $this.defaultParams + @{
            uri = "$( $this.baseUrl)Motifs"
        }
        $res = Invoke-AlphaPictures @params
        
        # Transform result to objects
        $motifs = [System.Collections.ArrayList]@()
        $res | ForEach {

            $motif = $_

            $motifObj = [Motif]@{
                id = $motif.id
                name = $motif.name
                created = $motif.creationdate
                updated = $motif.lastmodified
                alphaPictures = $this
                raw = $motif
            }
            $motifObj.setAlternatives($motif.alternatives)

            [void]$motifs.Add($motifObj)

        }

        return $motifs
  
    }


}




################################################
#
# OTHER FUNCTIONS
#
################################################

Function Invoke-AlphaPictures {

    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$false)][pscredential]$cred                                   # securestring containing username as user and secret as password
        ,[Parameter(Mandatory=$false)][System.Uri]$uri = "https://v4.alphapicture.com/"  # default url to use
        ,[Parameter(Mandatory=$false)][String]$method = "Get"
        ,[Parameter(Mandatory=$false)][String]$outFile = ""
        ,[Parameter(Mandatory=$false)][System.Object]$body = $null
        ,[Parameter(Mandatory=$false)][bool]$returnBase64 = $false
    )

    begin {

        #-----------------------------------------------
        # AUTH
        #-----------------------------------------------
        
        $password = $cred.GetNetworkCredential().Password
        $account = $cred.UserName


        #-----------------------------------------------
        # HEADER
        #-----------------------------------------------

        $contentType = "application/json;charset=utf-8"

        $headers = @{
            "APIV4-Account" = $account
            "APIV4-Password" = $password
        }

    }

    process {

        $params = @{
            Uri = $uri
            Method = $method
            Verbose = $true
            Headers = $headers
            ContentType = $contentType
        }

        if ( $body -ne $null ) {
            $params += @{
                "Body" = $body
            }
        }

        if ( $outFile -ne "" ) {
            $params += @{
                "OutFile" = $outFile
            }
        }

        if ( $returnBase64 ) {

            $params += @{
                "UseBasicParsing" = $true
            }
            
            $response = Invoke-WebRequest @params
            # From PS 6 onwards, use  bytestream instead: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/set-content?view=powershell-7.2            
            #set-content -Value $response.content -Path ".\test8.png" -Encoding Byte
            $result = [Convert]::ToBase64String( $response.content )

        } else {

            try {

                $result = Invoke-RestMethod @params
            
            } catch {
    
                ParseErrorForResponseBody -err $_
                # TODO [ ] Do something with the error
    
            }

        }

    }

    end {

        if ( $outFile -ne "" ) {

            $outFile

        } else {           
            
            $result

        }

    }

}

<#
Calc-Imagesize -sourceWidth 1250 -sourceHeight 500 -targetWidth 500
Calc-Imagesize -sourceWidth 1250 -sourceHeight 500 -targetHeight 500
#>

function Calc-Imagesize {

    [CmdletBinding()]
    param (
         [Parameter(Mandatory=$true)][int]$sourceWidth
        ,[Parameter(Mandatory=$true)][int]$sourceHeight
        ,[Parameter(Mandatory=$false)][int]$targetWidth = 0
        ,[Parameter(Mandatory=$false)][int]$targetHeight = 0
    )
    
    begin {

        # Check if target width or height is available
        if ( $targetWidth -gt 0 -or $targetHeight -gt 0 ) {
            #"Check is good, proceed"
        } else {
            throw [System.IO.InvalidDataException] "No target width or height available, please change call"
        }

        # Calculate image ratio
        $ratio = $sourceWidth/$sourceHeight

    }
    
    process {
        
        if ( $targetWidth -gt 0 ) {
            $width = $targetWidth
            $height = $targetWidth / $ratio
        } else {
            $width = $targetHeight * $ratio
            $height = $targetHeight
        }

    }
    
    end {

        #return 
        [PSCustomObject]@{
            width = [Math]::Round($width)
            height = [Math]::Round($height)
        }

    }
}