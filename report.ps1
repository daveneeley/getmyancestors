param (
$credential,
[int]$generations = 8,
$placeFilter = "\bIL\b|\bIA\b|iowa|illin",
[DateTime]$dateStart = '1830-01-01',
[DateTime]$dateEnd = '1850-12-31'
)
$file = '2017-07-26.txt'
if (!(test-path $file)) {
    if (!$credential) {
        $credential = Get-Credential
    }
    $netcred = $credential.GetNetworkCredential()
    $allData = python .\getmyancestors.py -u $netcred.username -p $netcred.password -a $generations -m -o $file 
}
$allData = cat $file | convertfrom-json

function sanitizeDate {
    param (
        $datestring
    )
    if ($datestring) {
        $sanitized = $datestring -replace "Ab(ou)?t(\s+)? ", "" -replace "Sept", "SEP" -replace "[<>]", "" -replace "^(\d{4})(\d{2})(\d{2})$", "`$1-`$2-`$3" -replace "^\d{4}$", "`$0-01-01"
        $date = get-date -date $sanitized
        if (!$date) {
            return $sanitized
        }
        return $date
    }
}

foreach ($placeprop in @('birtplac', 'chrplac', 'deatplac', 'buriplace')) {
    $dateprop = $placeprop -replace "plac", "date"
    $allData | ?{$_.$placeprop -match $placeFilter} | %{new-object PSobject -property @{placeprop=$placeprop;name=$($_.given + " " + $_.surname);place=$_.$placeprop;date=sanitizeDate($_.$dateprop);fid=$_.fid}} | select placeprop, date, name, place, fid | ?{!($_.date) -or ($_.date -ge $dateStart -and $_.date -le $dateEnd)} | sort date | Format-Table -autosize
}
$nearbymarriages = $allData | ?{$_.marrdate -and $_.marrplac -match $placeFilter} | %{
    $marRec = $_; 
    $hubby = $allData | ?{$_.given -and $_.num -eq $marRec.husb_num}; 
    $wifey = $allData | ?{$_.given -and $_.num -eq $marRec.wife_num}; 
    new-object psobject -Property @{placeprop='marrplac';date=$(sanitizeDate($marRec.marrdate)); place=$marrec.marrplac;hubby_name=$($hubby.given + " " + $hubby.surname); hubby_fid=$_.husb_fid; wifey_name=$($wifey.given + " " + $wifey.surname); wifey_fid=$_.wife_fid}}

$nearbymarriages | select placeprop, date, place, hubby_name, wifey_name, hubby_fid, wifey_fid | ?{!($_.date) -or ($_.date -ge $dateStart -and $_.date -le $dateEnd)} | sort date | Format-Table -autosize
