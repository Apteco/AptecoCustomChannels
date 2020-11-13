There are currently two possibilites to load new wallets from vibes/syniverse:

* Callback (push)
* Download (pull)

The callback method is more robust and scalable. When a wallet is installed or removed, then vibes/syniverse directly calls a callback url on the Apteco side so the server can react immediatly on those events. But this also means that you need a callback receiver in the cloud to notify the Apteco server.

The download method pulls the recent 50 new wallets. In that case you need to make sure that your customers do not create 50 wallets between two data downloads. And you need to sync wallet items you already know against new ones.

# Callback

An already existing callback server is needed to do this. When you have one, make sure you have one hook for new wallets and one for removed wallets. To setup the hooks on vibes/syniverse side, please make the following calls like here in PowerShell.

## Installed Wallets

To install a hook for new wallets, please make sure you replace `<compandyId>` and `<token>`

```
# Load settings
$baseUrl = "https://public-api.cm.syniverse.eu"
$companyId = "<companyId>"
$token = "<token>"

# Prepare headers
$headers = @{
    "Authorization"="Basic $( $token )"
    "X-API-Version"="2"
    "int-companyid"=$companyId
}
$contentType = "application/json" 

# Prepare body
$body = @{
    "event_type" = "wallet_item_install"
    "wallet_item_install" = @{
        "campaign_token" = "osdmeh"
    }
    "destination" = @{
        "url" = "http://webhooks.apteco.io/hooks/wallets-new"
        "method" = "POST"
        "content_type" = "application/json"
    }
}
$bodyJson = $body | ConvertTo-Json -Depth 8

# Prepare query
$callbackInstallUrl = "$( $baseUrl )/companies/$( $companyId )/config/callbacks/"

# Call the API
$resultInstall = Invoke-RestMethod -Method Post -Verbose -Uri $callbackInstallUrl -Body $bodyJson -ContentType $contentType -Headers $headers
```

If the callback is successfully installed, you get a message in the variable `$resultInstall` like this one (some values changed due to security):

```
callback_id         : 1151
event_type          : wallet_item_install
wallet_item_install : @{campaign_token=osdmeh}
destination         : @{url=https://www.example.com/hooks/wallets-new; method=POST; content_type=application/json}
start_date          : 2020-08-23T16:45:49Z
url                 : /companies/<companyId>/config/callbacks/1149
created_at          : 2020-08-23T16:45:49Z
updated_at          : 2020-08-23T16:45:49Z
```

## Removed Wallets

To install a hook for removed wallets, please make sure you replace `<compandyId>` and `<token>`


```
# Load settings
$baseUrl = "https://public-api.cm.syniverse.eu"
$companyId = "<companyId>"
$token = "<token>"

# Prepare headers
$headers = @{
    "Authorization"="Basic $( $token )"
    "X-API-Version"="2"
    "int-companyid"=$companyId
}
$contentType = "application/json" 

# Prepare body
$body = @{
    "event_type" = "wallet_item_remove"
    "wallet_item_install" = @{
        "campaign_token" = "osdmeh"
    }
    "destination" = @{
        "url" = "http://webhooks.apteco.io/hooks/wallets-remove"
        "method" = "POST"
        "content_type" = "application/json"
    }
}
$bodyJson = $body | ConvertTo-Json -Depth 8

# Prepare query
$callbackRemoveUrl = "$( $baseUrl )/companies/$( $companyId )/config/callbacks/"

# Call the API
$resultInstall = Invoke-RestMethod -Method Post -Verbose -Uri $callbackRemoveUrl -Body $bodyJson -ContentType $contentType -Headers $headers
```

If the callback is successfully installed, you get a message in the variable `$resultInstall` like this one (some values changed due to security):

```
callback_id        : 1152
event_type         : wallet_item_remove
wallet_item_remove : @{campaign_token=osdmeh}
destination        : @{url=https://www.example.com/hooks/wallets-remove; method=POST; content_type=application/json}
start_date         : 2020-08-23T18:12:46Z
url                : /companies/<companyId>/config/callbacks/1152
created_at         : 2020-08-23T18:12:46Z
updated_at         : 2020-08-23T18:12:46Z
```

## Example

If a wallet then gets created, the webhook server get notified with a payload like this one (some values changed):`

```
{
    "event_date": "2020-08-23T21:38:05.258+01:00",
    "event_id": "8498679c-108a-4378-aee0-54c9c4f06834",
    "event_type": "wallet_item_install",
    "wallet_campaign": {
        "token": "osdmeh",
        "url": "/companies/<companyId>/campaigns/wallet/osdmeh",
        "wallet_campaign_uid": "a5s8222d-1234-5678-a1a1-2d566a145s12"
    },
    "wallet_instance": {
        "provider": "apple",
        "registered_at": "2020-08-23T20:38:05.000Z",
        "unregistered_at": null,
        "wallet_instance_uid": "a65dsaf6asd46f4asdf32a4d2f24asdf4a3sd5f43sdf"
    },
    "wallet_item": {
        "expiration_date": "2020-12-31T17:00:00.000Z",
        "tokens": {
            "content1": "You can also book your demo now:https://www.apteco.com/book-a-demo",
            "first_name": "Bruce",
            "last_name": "Wayne",
            "points": "100",
            "qrcode": "23747364",
            "qrcodetext": "Thank You"
        },
        "url": "/companies/<companyId>/campaigns/wallet/osdmeh/items/7dc744de-1234-ea33-f312-3cecef2260ac",
        "uuid": "7dc744de-1234-ea33-f312-3cecef2260ac",
        "wallet_object_uid": "5ebe5d5d-1234-4444-9e66-57744e2c9e32"
    }
}
```

## Other

If you want to load all existing hooks or delete ones, just use it like these ones:

```
# Load callbacks and remove them e.g.
Invoke-RestMethod -Method Get -Headers $headers -ContentType $contentType -Uri "$( $baseUrl )/companies/$( $companyId )/config/callbacks" -Verbose
Invoke-RestMethod -Method Delete -Headers $headers -ContentType $contentType -Uri "$( $baseUrl )/companies/ZMCOdgA5/config/callbacks/1149" -Verbose
```

If you use your own webhooks service and need to setup the encryption security, the syniverse sending server supports the following ciphers

```
TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA
TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA
TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA
TLS_RSA_WITH_AES_128_GCM_SHA256
TLS_RSA_WITH_AES_256_GCM_SHA384
TLS_RSA_WITH_AES_128_CBC_SHA
TLS_RSA_WITH_AES_256_CBC_SHA
TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA
TLS_RSA_WITH_3DES_EDE_CBC_SHA
```

# Download 

Have a look at the PowerShell scripts in this folder...
