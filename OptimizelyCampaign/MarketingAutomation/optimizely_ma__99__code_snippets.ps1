

#-----------------------------------------------
# HTML CONTENT
#-----------------------------------------------
<#
$html = Invoke-Epi -webservice "Mailing" -method "getContent" -param @(261142993531,"text/html") -useSessionId $true
$html.getContentResponse.getContentReturn.'#text'
#>

#-----------------------------------------------
# GET WAVES
#-----------------------------------------------



<#
# get first row to see how many columns a row has
$firstRow = Invoke-Epi -webservice "ClosedLoop" -method "getMailings" -param @(($currentTimestamp - $secondsForXDays),$currentTimestamp,@{value=0;datatype="int"},@{value=1;datatype="int"}) -useSessionId $true #-verboseCall
$noOfColumns = $firstRow.getMailingsReturn.Count


# page through rows
$page = 1    
$waves = @()
do {
    
    # get data
    $start = ($page*$maxRows)-$maxRows
    $rowsForXDays = Invoke-Epi -webservice "ClosedLoop" -method "getMailings" -param @(($currentTimestamp - $secondsForXDays),$currentTimestamp,@{value=$start;datatype="int"},@{value=$maxRows;datatype="int"}) -useSessionId $true #-verboseCall

    $j = 0
    $i = 0
    $rowsForXDays.getMailingsReturn | ForEach {
            
        $rec = $_

        if ( $i % $noOfColumns -eq 0 ) {
            $row = New-Object PSCustomObject
            $j = 0
        }
 
        $row | Add-Member -MemberType NoteProperty -Name "Col$( $j )" -Value $rec
        $i += 1
        $j += 1

        if ( $i % $noOfColumns -eq 0 ) {
            $waves += $row
        }

    }
    
    # preparation for next page
    $page += 1

} until ( $rowsForXDays.getMailingsReturn.Count -lt ( $maxRows * $noOfColumns )  )

$waves | Export-Csv -Encoding UTF8 -NoTypeInformation -Path ".\$( $guid )\waves.csv" -Delimiter "`t"
#>
#-----------------------------------------------
# GET LINKS
#-----------------------------------------------

<#
# get first row to see how many columns a row has
$firstRow = Invoke-Epi -webservice "ClosedLoop" -method "getLinks" -param @(($currentTimestamp - $secondsForXDays),$currentTimestamp,@{value=0;datatype="int"},@{value=1;datatype="int"}) -useSessionId $true #-verboseCall
$noOfColumns = $firstRow.getLinksReturn.Count


# page through rows
$page = 1    
$links = @()
do {
    
    # get data
    $start = ($page*$maxRows)-$maxRows
    $rowsForXDays = Invoke-Epi -webservice "ClosedLoop" -method "getLinks" -param @(($currentTimestamp - $secondsForXDays),$currentTimestamp,@{value=$start;datatype="int"},@{value=$maxRows;datatype="int"}) -useSessionId $true #-verboseCall

    $j = 0
    $i = 0
    $rowsForXDays.getLinksReturn | ForEach {
            
        $rec = $_

        if ( $i % $noOfColumns -eq 0 ) {
            $row = New-Object PSCustomObject
            $j = 0
        }
 
        $row | Add-Member -MemberType NoteProperty -Name "Col$( $j )" -Value $rec
        $i += 1
        $j += 1

        if ( $i % $noOfColumns -eq 0 ) {
            $links += $row
        }

    }
    
    # preparation for next page
    $page += 1

} until ( $rowsForXDays.getLinksReturn.Count -lt ( $maxRows * $noOfColumns )  )

$links | Export-Csv -Encoding UTF8 -NoTypeInformation -Path ".\$( $guid )\links.csv" -Delimiter "`t"
#>