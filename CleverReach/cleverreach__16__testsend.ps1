# send preview
$preview = [pscustomobject]@{
    receivers = @("florian.von.bracht@apteco.de")
    previewText=" - have a look"
}
$previewJson = $preview | ConvertTo-Json -Depth 8 -Compress
$previewMailing = Invoke-RestMethod -Method POST -Uri "$( $mailingsUrl )/$( $copiedMailing.id )/sendpreview" -Headers $header -Verbose -Body $previewJson -ContentType $contentType
