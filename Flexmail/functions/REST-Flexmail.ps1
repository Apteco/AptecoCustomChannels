<#
Needs the $settings object first with 
$settings.login.username
$settings.login.token
$settings.base
#>
Function Create-Flexmail-Parameters {

    [CmdletBinding()]
    param ()

    begin {

    }
    
    process {


        #-----------------------------------------------
        # AUTH
        #-----------------------------------------------

        # https://pallabpain.wordpress.com/2016/09/14/rest-api-call-with-basic-authentication-in-powershell/

        # Step 2. Encode the pair to Base64 string
        $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$( $settings.login.user ):$( Get-SecureToPlaintext $settings.login.tokenREST )"))
        
        # Step 3. Form the header and add the Authorization attribute to it
        $script:headers = @{
            Authorization = "Basic $encodedCredentials"
        }

        
        #-----------------------------------------------
        # HEADER + CONTENTTYPE + BASICS
        #-----------------------------------------------

        $script:apiRoot = $settings.baseREST
        $script:contentType = "application/json" #"application/json; charset=utf-8"

        $script:headers += @{

        }

    }
    
    end {

    }

}