if ( $headers.Cookie ) {

    $logout = Invoke-RestMethod -Method Post -Uri "$( $settings.base )/account/logout.json" -ContentType $contentType -verbose -Headers $headers

}