# Get the api credentials from https://app.mailjet.com/account/api_keys
$user = "<apikey>"
$pass = "<secretKey>"


$body = [PSCustomObject]@{
  "Messages" = @(
    [PSCustomObject]@{
      "From" = [PSCustomObject]@{
        "Email" = "<email>"
        "Name" = "Florian"
      }
      "To" = @(
        [PSCustomObject]@{
          "Email" = "<email>"
          "Name" = "Florian"
        }
      )
      "Subject" = "My first Mailjet email"
      "TextPart" = "Greetings from Mailjet."
      "HTMLPart" = "<h3>Dear passenger 1, welcome to <a href='https://www.mailjet.com/'>Mailjet</a>!</h3><br />May the delivery force be with you!"
      "CustomID" = "AppGettingStartedTest"
    }
  )
}
$bodyJson = ConvertTo-Json -InputObject $body -Depth 8 -Compress


# Step 2. Encode the pair to Base64 string
$encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$( $user ):$( $pass )"))
        
# Step 3. Form the header and add the Authorization attribute to it
$headers = @{ Authorization = "Basic $encodedCredentials" }

$params = @{
  Method = "Post"
  Uri = "https://api.mailjet.com/v3.1/send"
  Verbose = $true
  ContentType = "application/json"
  Body = $bodyJson
  Headers = $headers
}

$res = Invoke-RestMethod  @params

<#
# This is the result that is delivered back
{
    "Status":  "success",
    "CustomID":  "AppGettingStartedTest",
    "To":  [
               {
                   "Email":  "florian.von.bracht@apteco.de",
                   "MessageUUID":  "c840588d-337d-406f-9bb5-a57284151894",
                   "MessageID":  288230382218376224,
                   "MessageHref":  "https://api.mailjet.com/v3/REST/message/288230382218376224"
               }
           ],
    "Cc":  [

           ],
    "Bcc":  [

            ]
}

#>
