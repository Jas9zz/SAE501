#############################################################################
# REMDCSRV - Installation Active Directory Domain Services
# Site: Remote (WorldSkills France)
# Domaine: rem.wsl2025.org (enfant de wsl2025.org)
#############################################################################

# Variables
$DomainName = "rem.wsl2025.org"
$ParentDomain = "wsl2025.org"
$NetBIOSName = "REM"
$SafeModePassword = ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force
$ParentDCIP = "10.3.10.1"  # DCWSL ou HQDCSRV

Write-Host "=== Installation d'Active Directory Domain Services ===" -ForegroundColor Cyan

#--- Vérification de la connectivité au domaine parent ---
Write-Host "[1/5] Vérification de la connectivité au domaine parent..." -ForegroundColor Yellow
if (!(Test-Connection -ComputerName $ParentDCIP -Count 2 -Quiet)) {
    Write-Host "ERREUR: Impossible de joindre le DC parent ($ParentDCIP)" -ForegroundColor Red
    Write-Host "Vérifiez la connectivité réseau et réessayez." -ForegroundColor Red
    exit 1
}
Write-Host "    Connectivité OK vers $ParentDCIP" -ForegroundColor Green

#--- Installation du rôle AD DS ---
Write-Host "[2/5] Installation du rôle AD DS..." -ForegroundColor Yellow
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -Verbose

#--- Installation des outils RSAT ---
Write-Host "[3/5] Installation des outils RSAT..." -ForegroundColor Yellow
Install-WindowsFeature -Name RSAT-AD-Tools, RSAT-DNS-Server, RSAT-DHCP -Verbose

#--- Credentials du domaine parent ---
Write-Host "[4/5] Préparation des credentials..." -ForegroundColor Yellow
Write-Host "    Entrez les credentials d'un administrateur du domaine parent ($ParentDomain)" -ForegroundColor Yellow
$Credential = Get-Credential -Message "Entrez les credentials pour $ParentDomain (ex: wsl2025\Administrator)"

#--- Promotion en contrôleur de domaine enfant ---
Write-Host "[5/5] Promotion en contrôleur de domaine enfant..." -ForegroundColor Yellow
Write-Host "    Domaine enfant: $DomainName" -ForegroundColor Cyan
Write-Host "    Domaine parent: $ParentDomain" -ForegroundColor Cyan

Import-Module ADDSDeployment

Install-ADDSDomain `
    -NewDomainName "rem" `
    -ParentDomainName $ParentDomain `
    -DomainType ChildDomain `
    -DomainMode WinThreshold `
    -InstallDns:$true `
    -CreateDnsDelegation:$true `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SysvolPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $SafeModePassword `
    -Credential $Credential `
    -NoRebootOnCompletion:$false `
    -Force:$true

Write-Host "`n=== Le serveur va redémarrer automatiquement ===" -ForegroundColor Green
Write-Host "Après le redémarrage, exécutez le script 03-Configure-DNS.ps1" -ForegroundColor Yellow
