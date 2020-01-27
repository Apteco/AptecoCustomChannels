<#

POST /api/push HTTP/1.1
Authorization: Basic <master authorization string>
Accept: application/vnd.urbanairship+json; version=3;
Content-Type: application/json

{
    "audience": {
        "ios_channel": "9c36e8c7-5a73-47c0-9716-99fd3d4197d5"
    },
    "notification": {
        "alert": "Hello!"
    },
    "device_types": [ "ios" ]
}

# Whole Push Object documentation:
https://docs.airship.com/api/ua/#schemas/pushobject


#>

$baseUrl = "https://go.airship.eu"
$contentType = "application/json"
$headers = @{
    "Accept" = "application/vnd.urbanairship+json; version=3;"
    "Authorization" = "Basic <master authorization string>"
}

# the body push object can also be an array with max of 100 objects
$body = @{

    # https://docs.airship.com/api/ua/#schemas%2faudienceselector
    "audience" = @{ 
        "ios_channel" = "9c36e8c7-5a73-47c0-9716-99fd3d4197d5"
    }

    # https://docs.airship.com/api/ua/#schemas%2fcampaignsobject
    #"campaigns" = @{"categories"=@()}

    #"in_app" = @{} # https://docs.airship.com/api/ua/#schemas%2finappobject

    "notification" = @{
        "alert" = "Hello world!"
    }

    # available on Android, iOS, Amazon, and Web audiences
    <#
    "localizations" = @(
        @{
            "language" = "de"
            "country" = "AT"
            "notification" = @{
                "alert" = "Grüss Gott"
            }
        },
        @{
            "language" = "de"
            "country" = "DE"
            "notification" = @{
                "alert" = "Guten Tag"
            }
        }
    )
    #>
    
    # https://docs.airship.com/api/ua/#schemas%2fmessageobject
    <#
    "message" = @{
        "title" = "This week's offer"
        "body" = "<html><body><h1>blah blah</h1> etc...</html>"
        "content_type" = "text/html"
        "expiry" = "2015-04-01T12:00:00"
        "extra" = @{
            "offer_id" = "608f1f6c-8860-c617-a803-b187b491568e"
        }
        "icons" = @{
            "list_icon" = "http://cdn.example.com/message.png"
        }
        "options" = @{
            "some_delivery_option" = $true
        }
    }
    #>

    "device_types" = @("ios") # ios|android|amazon|wns|web|sms|email

    <#
    "options" = @{
        "expiry" = "2017-04-01T12:00:00"
    }
    #>

}
$bodyJson = $body | ConvertTo-Json -Depth 8
$url = "$( $baseUrl )/api/push"
#$response = Invoke-RestMethod -Uri $url -Headers $headers -Method Post -ContentType $contentType -Body $bodyJson