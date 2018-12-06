#Hleð inn klösum fyrir GUI, svipað og References í C#
[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
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
#Breytan notendur er hashtafla sem heldur utan um alla notendur sem finnast, 
#breytan þarf að vera "global" innan skriptunnar
$Script:notendur = @{} 

#Fall sem sér um að leita að notendum og skilar niðurstöðunni í ListBox-ið
function LeitaAdNotendum  {
    #útbý leitarstrenginn set * sitthvoru megin við það sem er í textaboxinu
    $leitarstrengur = "*" + $txtLeita.Text + "*"
    #finn alla notendur þar sem leitarstrengurinn kemur fram í nafninu, tek nafnið
    #og samaccountname, nafnið birti ég en nota svo samaccount til að fá frekari
    #upplýsingar um notanda sem valinn er. Set þetta í global notendur breytuna
    $Script:notendur = Get-ADUser -Filter { name -like $leitarstrengur } -searchbase "ou=nemendur, ou=notendur, dc=bjatli-xdd, dc=local" | select name, samaccountname
    #set svo niðurstöðurnar í listboxið
    foreach($notandi in $Script:notendur) {
        $lstNidurstodur.Items.Add($notandi.name)
    }
}

function NotandiValinn {
    Write-Host $Script:notendur[$lstNidurstodur.SelectedIndex].samaccountname
    $lblSynaNafn.Text = ""
    $lblSynaNafn.Text = ($Script:notendur[$lstNidurstodur.SelectedIndex].name)
}
function LeitaAdOU  {
    $leita = "*" + $txtGroup.Text + "*"
    $Script:OU = Get-ADOrganizationalUnit -Filter { name -like $leita } -SearchBase "ou=upplýsingatækniskólinn, ou=nemendur, ou=notendur, dc=bjatli-xdd, dc=local" | select name
    #set svo niðurstöðurnar í listboxið
    foreach($o in $Script:OU) {
        $lstOUNidurstodur.Items.Add($o.name)
    }
}

function OUValid {
    Write-Host $Script:OU[$lstOUNidurstodur.SelectedIndex].name
    $lblSynaOU.Text = ""
    $lblSynaOU.Text = ($Script:notendur[$lstNidurstodur.SelectedIndex].name)
}

function Enable {
    Enable-ADAccount -Identity $Script:notendur[$lstNidurstodur.SelectedIndex].samaccountname
    Write-Host "Account enabled"
}
function Disable {
    Disable-ADAccount -Identity $Script:notendur[$lstNidurstodur.SelectedIndex].samaccountname
    Write-Host "Account disabled"
}
function BreytaPassword {
    Set-ADAccountPassword -Identity $Script:notendur[$lstNidurstodur.SelectedIndex].samaccountname -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $txtPassword.text -Force)
    $txtPassword.text = ""
    Write-Host "Lykilorði hefur verið breytt"
}

function CreateUser{
    $listi = $txtUserName.Text.Split(" ")
    $notendanafn = notendanafn_nemenda($txtUserName.Text)
    $braut = $Script:OU[$lstOUNidurstodur.SelectedIndex].name
    $userInfo = @{
        Name = $txtUserName.Text
        DisplayName = $notendanafn
        GivenName =$txtUserName.Text.Replace($listi[-1],"").trim()
        Surname = $listi[-1]
        SamAccountName = $notendanafn
        UserPrincipalName = $($notendanafn + "@" + $env:USERDNSDOMAIN)
        AccountPassword = (convertTo-SecureString -AsPlainText "pass.123" -force)
        Path = $("ou=" + $braut + ",ou=upplýsingatækniskólinn, ou=nemendur, ou=notendur, dc=" + $env:USERDNSDOMAIN.split(".")[0] +  ", dc=" + $env:USERDNSDOMAIN.Split(".")[1])
        Enabled = $true
    }
    New-ADUser @userInfo
    $slod = $notendanafn
    Add-DnsServerResourceRecordA -ZoneName "xxd.is" -Name $slod -IPv4Address "10.10.0.1"
    New-Item $("C:\inetpub\wwwroot\"+$slod) -ItemType Directory
    New-Item $("C:\inetpub\wwwroot\"+$slod+"\index.html") -ItemType File -Value $("Vefsíðan" + $slod)
    New-Website -Name $slod -HostHeader $slod -PhysicalPath $("C:\inetpub\wwwroot\"+$slod+"\")
    Write-Host "Notandi búinn til"
}

#Aðalglugginn 
#Bý til tilvik af Form úr Windows Forms
$frmLeita = New-Object System.Windows.Forms.Form
#Set stærðina á forminu
$frmLeita.ClientSize = New-Object System.Drawing.Size(550,400)
#Set titil á formið
$frmLeita.Text = "Leita að notendum"

#Leita takkinn
#Bý til tilvik af Button
$btnLeita = New-Object System.Windows.Forms.Button
#Set staðsetningu á takkanum
$btnLeita.Location = New-Object System.Drawing.Point(300,25)
#Set stærðina á takkanum
$btnLeita.Size = New-Object System.Drawing.Size(75,25)
#Set texta á takkann
$btnLeita.Text = "Leita"
#Bý til event sem keyrir þegar smellt er á takkann. Þegar smellt er á takkan á að kalla í fallið LeitaAdNotendum
$btnLeita.add_Click({ LeitaAdNotendum })
#Sett takkann á formið
$frmLeita.Controls.Add($btnLeita)

#Label Nafn:
#Bý til tilvik af Label
$lblNafn = New-Object System.Windows.Forms.Label
#Set staðsetningu á label-inn
$lblNafn.Location = New-Object System.Drawing.Point(30,30)
#Set stærðina
$lblNafn.Size = New-Object System.Drawing.Size(50,20)
#Set texta á 
$lblNafn.Text = "Nafn:"
#Set label-inn á formið
$frmLeita.Controls.Add($lblNafn)

#Textabox fyrir leitarskilyrðin
#Bý til tilvik af TextBox
$txtLeita = New-Object System.Windows.Forms.TextBox
#Set staðsetninguna
$txtLeita.Location = New-Object System.Drawing.Point(80,30)
#Set stærðina
$txtLeita.Size = New-Object System.Drawing.Size(210,30)
#Set textboxið á formið
$frmLeita.Controls.Add($txtLeita)

#Listbox fyrir leitarniðurstöður
#Bý til tilvik af ListBox
$lstNidurstodur = New-Object System.Windows.Forms.ListBox
#Set staðsetningu
$lstNidurstodur.Location = New-Object System.Drawing.Point(80,60)
#Set stærðina
$lstNidurstodur.Size = New-Object System.Drawing.Size(210,100)
#Bý til event sem keyrir þegar eitthvað er valið í listboxinu, kalla þá í fallið NotandiValinn
$lstNidurstodur.add_SelectedIndexChanged( { NotandiValinn } )
#Set listboxið á formið
$frmLeita.Controls.Add($lstNidurstodur)

$btnPass = New-Object System.Windows.Forms.Button
#Set staðsetningu á takkanum
$btnPass.Location = New-Object System.Drawing.Point(300,60)
#Set stærðina á takkanum
$btnPass.Size = New-Object System.Drawing.Size(75,25)
#Set texta á takkann
$btnPass.Text = "Password"
#Bý til event sem keyrir þegar smellt er á takkann. Þegar smellt er á takkan á að kalla í fallið LeitaAdNotendum
$btnPass.add_Click({ BreytaPassword })
#Sett takkann á formið
$frmLeita.Controls.Add($btnPass)

$btnenable = New-Object System.Windows.Forms.Button
#Set staðsetningu á takkanum
$btnenable.Location = New-Object System.Drawing.Point(300,120)
#Set stærðina á takkanum
$btnenable.Size = New-Object System.Drawing.Size(75,25)
#Set texta á takkann
$btnenable.Text = "Enable"
#Bý til event sem keyrir þegar smellt er á takkann. Þegar smellt er á takkan á að kalla í fallið LeitaAdNotendum
$btnenable.add_Click({ Enable })
#Sett takkann á formið
$frmLeita.Controls.Add($btnenable)

$btnDisable = New-Object System.Windows.Forms.Button
#Set staðsetningu á takkanum
$btnDisable.Location = New-Object System.Drawing.Point(300,150)
#Set stærðina á takkanum
$btnDisable.Size = New-Object System.Drawing.Size(75,25)
#Set texta á takkann
$btnDisable.Text = "Disable"
#Bý til event sem keyrir þegar smellt er á takkann. Þegar smellt er á takkan á að kalla í fallið LeitaAdNotendum
$btnDisable.add_Click({ Disable })
#Sett takkann á formið
$frmLeita.Controls.Add($btnDisable)

$lblSynaNafn = New-Object System.Windows.Forms.Label
#Set staðsetningu
$lblSynaNafn.Location = New-Object System.Drawing.Point(80,160)
#Set stærðina
$lblSynaNafn.Size = New-Object System.Drawing.Size(200,20)
#Bý til event sem keyrir þegar eitthvað er valið í listboxinu, kalla þá í fallið NotandiValinn
$lblSynaNafn.Text = ""
#Set listboxið á formið
$frmLeita.Controls.Add($lblSynaNafn)

$txtPassword = New-Object System.Windows.Forms.TextBox
#Set staðsetninguna
$txtPassword.Location = New-Object System.Drawing.Point(300,90)
#Set stærðina
$txtPassword.Size = New-Object System.Drawing.Size(220,30)
#Set textboxið á formið
$frmLeita.Controls.Add($txtPassword)

$txtUserName = New-Object System.Windows.Forms.TextBox
#Set staðsetninguna
$txtUserName.Location = New-Object System.Drawing.Point(80,200)
#Set stærðina
$txtUserName.Size = New-Object System.Drawing.Size(210,30)
#Set textboxið á formið
$frmLeita.Controls.Add($txtUserName)

$txtPasswordNytt = New-Object System.Windows.Forms.TextBox
#Set staðsetninguna
$txtPasswordNytt.Location = New-Object System.Drawing.Point(80,250)
#Set stærðina
$txtPasswordNytt.Size = New-Object System.Drawing.Size(210,30)
#Set textboxið á formið
$frmLeita.Controls.Add($txtPasswordNytt)

$lblUserName = New-Object System.Windows.Forms.Label
#Set staðsetningu á label-inn
$lblUserName.Location = New-Object System.Drawing.Point(80,180)
#Set stærðina
$lblUserName.Size = New-Object System.Drawing.Size(100,20)
#Set texta á 
$lblUserName.Text = "Notendanafn:"
#Set label-inn á formið
$frmLeita.Controls.Add($lblUserName)

$lblPassword = New-Object System.Windows.Forms.Label
#Set staðsetningu á label-inn
$lblPassword.Location = New-Object System.Drawing.Point(80,230)
#Set stærðina
$lblPassword.Size = New-Object System.Drawing.Size(50,20)
#Set texta á 
$lblPassword.Text = "Lykilorð:"
#Set label-inn á formið
$frmLeita.Controls.Add($lblPassword)

$btnCreateUser = New-Object System.Windows.Forms.Button
#Set staðsetningu á takkanum
$btnCreateUser.Location = New-Object System.Drawing.Point(80,330)
#Set stærðina á takkanum
$btnCreateUser.Size = New-Object System.Drawing.Size(100,25)
#Set texta á takkann
$btnCreateUser.Text = "Búa til notanda"
#Bý til event sem keyrir þegar smellt er á takkann. Þegar smellt er á takkan á að kalla í fallið LeitaAdNotendum
$btnCreateUser.add_Click({ CreateUser })
#Sett takkann á formið
$frmLeita.Controls.Add($btnCreateUser)

$txtGroup = New-Object System.Windows.Forms.TextBox
#Set staðsetninguna
$txtGroup.Location = New-Object System.Drawing.Point(300,200)
#Set stærðina
$txtGroup.Size = New-Object System.Drawing.Size(210,30)
#Set textboxið á formið
$frmLeita.Controls.Add($txtGroup)

$lblGroup = New-Object System.Windows.Forms.Label
#Set staðsetningu á label-inn
$lblGroup.Location = New-Object System.Drawing.Point(300,180)
#Set stærðina
$lblGroup.Size = New-Object System.Drawing.Size(100,20)
#Set texta á 
$lblGroup.Text = "Braut:"
#Set label-inn á formið
$frmLeita.Controls.Add($lblGroup)

$lstOUNidurstodur = New-Object System.Windows.Forms.ListBox
#Set staðsetningu
$lstOUNidurstodur.Location = New-Object System.Drawing.Point(300,230)
#Set stærðina
$lstOUNidurstodur.Size = New-Object System.Drawing.Size(210,100)
#Bý til event sem keyrir þegar eitthvað er valið í listboxinu, kalla þá í fallið NotandiValinn
$lstOUNidurstodur.add_SelectedIndexChanged( { OUValid } )
#Set listboxið á formið
$frmLeita.Controls.Add($lstOUNidurstodur)

$btnLeitaGroup = New-Object System.Windows.Forms.Button
#Set staðsetningu á takkanum
$btnLeitaGroup.Location = New-Object System.Drawing.Point(436,178)
#Set stærðina á takkanum
$btnLeitaGroup.Size = New-Object System.Drawing.Size(75,25)
#Set texta á takkann
$btnLeitaGroup.Text = "Leita"
#Bý til event sem keyrir þegar smellt er á takkann. Þegar smellt er á takkan á að kalla í fallið LeitaAdNotendum
$btnLeitaGroup.add_Click({ LeitaAdOU })
#Sett takkann á formið
$frmLeita.Controls.Add($btnLeitaGroup)

$lblSynaOU = New-Object System.Windows.Forms.Label
#Set staðsetningu
$lblSynaOU.Location = New-Object System.Drawing.Point(300,360)
#Set stærðina
$lblSynaOU.Size = New-Object System.Drawing.Size(100,20)
#Bý til event sem keyrir þegar eitthvað er valið í listboxinu, kalla þá í fallið NotandiValinn
$lblSynaOU.Text = ""
#Set listboxið á formið
$frmLeita.Controls.Add($lblSynaOU)

#Birti formið
$frmLeita.ShowDialog()

