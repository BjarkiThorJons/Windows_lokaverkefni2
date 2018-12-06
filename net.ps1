$tolvu = Get-ADGroupMember -Identity "AllirNemendurUpplýsingatækniskólinnTölvubraut"
foreach($n in $tolvu){
    $slod = $n.samaccountname
    Add-DnsServerResourceRecordA -ZoneName "xxd.is" -Name $slod -IPv4Address "10.10.0.1"
    New-Item $("C:\inetpub\wwwroot\"+$slod+"\index.html") -ItemType File -Value $("Vefsíðan" + $slod)
    New-Website -Name $slod -HostHeader $slod -PhysicalPath $("C:\inetpub\wwwroot\"+$slod+"\")
}
