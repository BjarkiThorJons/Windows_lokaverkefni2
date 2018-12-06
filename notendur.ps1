
$domainNafn = "bjatli-xdd.local"

function netadapter(){
    param(
        [Parameter(Mandatory=$true, HelpMessage="Ip address")]
        [string]$ipaddress
    )
    $theNetAdapter = Get-NetIPAddress -IPAddress $ipaddress
    return $theNetAdapter.InterfaceAlias
}

function breyta_stofum {
   param(
    [string]$nafn
    )
    $nafn = $nafn.ToLower()
    $nafn = $nafn.Replace("á","a")
    $nafn = $nafn.Replace("ó","o")
    $nafn = $nafn.Replace("í","i")
    $nafn = $nafn.Replace("ö","o")
    $nafn = $nafn.Replace("ð","d")
    $nafn = $nafn.Replace("þ","th")
    $nafn = $nafn.Replace("ý","y")
    $nafn = $nafn.Replace("ú","u")
    $nafn = $nafn.Replace("é","e")
    $nafn = $nafn.Replace("æ","ae")
    $nafn
}
function notendanafn_nemenda(){
    param(
    [string]$nafn
    )
    $listi = $nafn -split " "
    $notendanafn = $($listi[0].substring(0,2)+$listi[-1].substring(0,2))
    $leita = $notendanafn + "*"
    $nofn = Get-ADUser -Filter { samaccountname -like $leita }
    $notendanafn = breyta_stofum($notendanafn)
    if($nofn -is [array]){
         $notendanafn =$notendanafn+($nofn.Length+1)
    }
    elseif($nofn -is [object]){
        $notendanafn =$notendanafn+2
    }
    else{
         $notendanafn = $notendanafn+1 
    }
    return $notendanafn
}
function notendanafn_starfsmanna(){
    param(
    [string]$nafn
    )
    $list = $nafn -split " "
    $notendanafn = ""
    foreach($s in $list){
        $notendanafn = $notendanafn + "." +$s
    }
    $notendanafn = breyta_stofum($notendanafn.substring(1))
    $notendanafn = $notendanafn.Replace("..",".")
    if($notendanafn.Length -gt 20){
        $notendanafn = $notendanafn.substring(0,20)
    }
    if($notendanafn[-1] -eq "."){
        $notendanafn = $notendanafn.substring(0,19)
    }
    return $notendanafn
}


# Nettur netari EKKI KEYRA STRAX
Rename-NetAdapter -Name (netadapter -ipaddress 169.254.*) -NewName "LAN"
New-NetIPAddress -InterfaceAlias "LAN" -IPAddress  10.10.0.1 -PrefixLength 20
Set-DnsClientServerAddress -InterfaceAlias "LAN" -ServerAddresses 127.0.0.1

# AD-DS role
Install-WindowsFeature -Name ad-domain-services -IncludeManagementTools

# Promote server í DC
Install-ADDSForest -DomainName $domainNafn -InstallDns -SafeModeAdministratorPassword (ConvertTo-SecureString -AsPlainText "pass.123" -Force)

# REB00TY-----------------------------------------------------------

# Setja inn DHCP role
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# DHCP SCOPE
Add-DhcpServerv4Scope -Name scopedope -StartRange 10.10.0.3 -EndRange 10.10.9.200 -SubnetMask 255.255.248.0

Set-DhcpServerv4OptionValue -DnsServer 10.10.0.1 -Router 10.10.0.1
Add-DhcpServerInDC $($env:COMPUTERNAME + "." + $env:USERDNSDOMAIN)

# --------------
$passw = ConvertTo-SecureString -AsPlainText "2015P@ssword" -Force
$win8otandi = New-Object System.Management.Automation.PSCredential -ArgumentList $("win3a-w81-03\administrator"), $passw



$serverNotandi = New-Object System.Management.Automation.PSCredential -ArgumentList $($env:USERDOMAIN + "\administrator"), $passw


# Setja win8 vél á domain
Add-Computer -ComputerName "win3a-w81-05" -LocalCredential $win8otandi -DomainName $env:USERDNSDOMAIN -Credential $serverNotandi -Restart -Force

# OU fyrir tölvur
New-ADOrganizationalUnit -Name Tölvur -ProtectedFromAccidentalDeletion $false

# færa win8 vél í ou tölvur
Move-ADObject -Identity win3a-w81-05


#----------------------------------------------------------------------------------------------------------------------#
#----------------------------------------------------------------------------------------------------------------------#
#----------------------------------------------------------------------------------------------------------------------#

New-ADOrganizationalUnit Notendur -ProtectedFromAccidentalDeletion $false
New-ADGroup -Name Allir -Path $("ou=notendur,dc=" + $env:USERDNSDOMAIN.split(".")[0] +  ", dc=" + $env:USERDNSDOMAIN.Split(".")[1]) -GroupScope Global 

New-ADOrganizationalUnit Starfsmenn -Path $("ou=notendur, dc=" + $env:USERDNSDOMAIN.split(".")[0] +  ", dc=" + $env:USERDNSDOMAIN.Split(".")[1]) -ProtectedFromAccidentalDeletion $false
New-ADGroup -Name Starfsmenn -Path $("ou=Starfsmenn, ou=notendur, dc=" + $env:USERDNSDOMAIN.split(".")[0] +  ", dc=" + $env:USERDNSDOMAIN.Split(".")[1]) -GroupScope Global

Install-WindowsFeature web-server -IncludeManagementTools
Add-DnsServerPrimaryZone -Name "eep.is" -ReplicationScope Domain

$notendur = Import-Csv .\lokaverk_notendur.csv


foreach($n in $notendur) {
    $hlutverk = $n.Hlutverk
    $skoli = $n.Skoli
    $braut = $n.Braut
    if($n.Hlutverk -ne "Kennarar"){
        $SlodAStarfsmenn = ""
    }
    else {
        $SlodAStarfsmenn = "ou=Starfsmenn, "
    }

    if((Get-ADOrganizationalUnit -Filter { name -eq $hlutverk}).Name -ne $hlutverk){
        New-ADOrganizationalUnit -Name $hlutverk -Path $($SlodAStarfsmenn + "ou=notendur, dc=" + $env:USERDNSDOMAIN.split(".")[0] +  ", dc=" + $env:USERDNSDOMAIN.Split(".")[1]) -ProtectedFromAccidentalDeletion $false
        New-ADGroup -Name $hlutverk -Path $("ou="+$hlutverk + ", " + $SlodAStarfsmenn +"ou=notendur, dc=" + $env:USERDNSDOMAIN.split(".")[0] +  ", dc=" + $env:USERDNSDOMAIN.Split(".")[1]) -GroupScope Global
        Add-ADGroupMember -Identity Allir -Members $hlutverk
    }

    if((Get-ADOrganizationalUnit -SearchBase $("ou=" + $hlutverk + ", " + $SlodAStarfsmenn +" ou=notendur, dc=" + $env:USERDNSDOMAIN.split(".")[0] +  ", dc=" + $env:USERDNSDOMAIN.Split(".")[1]) -Filter { name -eq $skoli}).Name -ne $skoli){
        New-ADOrganizationalUnit -Name $skoli -Path $("ou=" + $hlutverk + ", " + $SlodAStarfsmenn + " ou=notendur, dc=" + $env:USERDNSDOMAIN.split(".")[0] +  ", dc=" + $env:USERDNSDOMAIN.Split(".")[1]) -ProtectedFromAccidentalDeletion $false
        New-ADGroup -Name $("Allir" + $hlutverk + $skoli) -Path $("ou=" + $skoli + ",ou=" + $hlutverk + ", " + $SlodAStarfsmenn +  " ou=notendur, dc=" + $env:USERDNSDOMAIN.split(".")[0] +  ", dc=" + $env:USERDNSDOMAIN.Split(".")[1]) -GroupScope Global
        Add-ADGroupMember -Identity $hlutverk -Members $("Allir" + $hlutverk + $skoli)
    }

    if((Get-ADOrganizationalUnit -SearchBase $("ou=" + $skoli + ", ou=" + $hlutverk + ", " + $SlodAStarfsmenn +" ou=notendur, dc=" + $env:USERDNSDOMAIN.split(".")[0] +  ", dc=" + $env:USERDNSDOMAIN.Split(".")[1]) -Filter { name -eq $braut}).Name -ne $braut){
        New-ADOrganizationalUnit -Name $braut -Path $("ou=" + $skoli + ", ou=" + $hlutverk + ", " + $SlodAStarfsmenn +  " ou=notendur, dc=" + $env:USERDNSDOMAIN.split(".")[0] +  ", dc=" + $env:USERDNSDOMAIN.Split(".")[1]) -ProtectedFromAccidentalDeletion $false
        New-ADGroup -Name $("Allir" + $hlutverk + $skoli + $braut.split(" ")[0]) -Path $("ou=" + $braut + ",ou=" + $skoli + ", ou=" + $hlutverk + ", " + $SlodAStarfsmenn +  " ou=notendur, dc=" + $env:USERDNSDOMAIN.split(".")[0] +  ", dc=" + $env:USERDNSDOMAIN.Split(".")[1]) -GroupScope Global
        Add-ADGroupMember -Identity $("Allir" + $hlutverk + $skoli) -Members $("Allir" + $hlutverk + $skoli + $braut.split(" ")[0])
    }
    #Notandi
    $listi = $n.Nafn.Split(" ")
    if($n.Hlutverk -eq "Nemendur"){
        $notendanafn = notendanafn_nemenda($n.Nafn)
    }
    else{
        $notendanafn = notendanafn_starfsmanna($n.Nafn)
    }
    $userInfo = @{
        Name = $n.Nafn
        DisplayName = $n.Nafn
        GivenName = $n.Nafn.Replace($listi[-1],"").trim()
        Surname = $listi[-1]
        SamAccountName = $notendanafn
        UserPrincipalName = $($notendanafn + "@" + $env:USERDNSDOMAIN)
        AccountPassword = (convertTo-SecureString -AsPlainText "pass.123" -force)
        Path = $("ou=" + $braut + ",ou=" + $skoli + ", ou=" + $hlutverk + ", " + $SlodAStarfsmenn +  " ou=notendur, dc=" + $env:USERDNSDOMAIN.split(".")[0] +  ", dc=" + $env:USERDNSDOMAIN.Split(".")[1])
        Enabled = $true
    }
    New-ADUser @userInfo
    Add-ADGroupMember -Identity $("Allir" + $hlutverk + $skoli + $braut.split(" ")[0]) -Members $notendanafn
}
#----------------------------------------------------------------------------------------------------------------------#
#----------------------------------------------------------------------------------------------------------------------#
#----------------------------------------------------------------------------------------------------------------------#