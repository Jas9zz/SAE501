#############################################################################
# REMDCSRV - Configuration DHCP
# Site: Remote (WorldSkills France)
# Scope: 10.3.100.0/24
#############################################################################

# Variables
$ScopeName = "Remote_Clients"
$ScopeID = "10.3.100.0"
$SubnetMask = "255.255.255.0"
$StartRange = "10.3.100.10"
$EndRange = "10.3.100.200"
$Gateway = "10.3.100.254"
$DNSServer = "10.3.100.1"  # REMDCSRV lui-même
$DNSDomain = "rem.wsl2025.org"
$NTPServer = "10.3.10.3"  # HQINFRASRV
$LeaseDuration = "0.02:00:00"  # 2 heures

Write-Host "=== Configuration DHCP sur REMDCSRV ===" -ForegroundColor Cyan

#--- Installation du rôle DHCP ---
Write-Host "[1/8] Installation du rôle DHCP Server..." -ForegroundColor Yellow
if (!(Get-WindowsFeature -Name DHCP).Installed) {
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
    Write-Host "    Rôle DHCP installé" -ForegroundColor Green
} else {
    Write-Host "    Rôle DHCP déjà installé" -ForegroundColor Yellow
}

#--- Autorisation du serveur DHCP dans AD ---
Write-Host "[2/8] Autorisation du serveur DHCP dans Active Directory..." -ForegroundColor Yellow
try {
    Add-DhcpServerInDC -DnsName "remdcsrv.rem.wsl2025.org" -IPAddress "10.3.100.1"
    Write-Host "    Serveur DHCP autorisé dans AD" -ForegroundColor Green
} catch {
    Write-Host "    Serveur déjà autorisé ou erreur: $_" -ForegroundColor Yellow
}

#--- Suppression du flag de configuration post-installation ---
Write-Host "[3/8] Configuration post-installation..." -ForegroundColor Yellow
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12" -Name "ConfigurationState" -Value 2 -ErrorAction SilentlyContinue

#--- Création du scope DHCP ---
Write-Host "[4/8] Création du scope DHCP..." -ForegroundColor Yellow
if (!(Get-DhcpServerv4Scope -ScopeId $ScopeID -ErrorAction SilentlyContinue)) {
    Add-DhcpServerv4Scope `
        -Name $ScopeName `
        -StartRange $StartRange `
        -EndRange $EndRange `
        -SubnetMask $SubnetMask `
        -LeaseDuration $LeaseDuration `
        -State Active
    Write-Host "    Scope créé: $ScopeName ($ScopeID)" -ForegroundColor Green
} else {
    Write-Host "    Scope existe déjà" -ForegroundColor Yellow
}

#--- Configuration des options du scope ---
Write-Host "[5/8] Configuration des options du scope..." -ForegroundColor Yellow

# Option 003 - Passerelle par défaut (Router)
Set-DhcpServerv4OptionValue -ScopeId $ScopeID -OptionId 3 -Value $Gateway
Write-Host "    Option 003 (Router): $Gateway" -ForegroundColor Green

# Option 006 - Serveur DNS
Set-DhcpServerv4OptionValue -ScopeId $ScopeID -OptionId 6 -Value $DNSServer
Write-Host "    Option 006 (DNS Server): $DNSServer" -ForegroundColor Green

# Option 015 - Nom de domaine DNS
Set-DhcpServerv4OptionValue -ScopeId $ScopeID -OptionId 15 -Value $DNSDomain
Write-Host "    Option 015 (DNS Domain): $DNSDomain" -ForegroundColor Green

# Option 042 - Serveur NTP
Set-DhcpServerv4OptionValue -ScopeId $ScopeID -OptionId 42 -Value $NTPServer
Write-Host "    Option 042 (NTP Server): $NTPServer" -ForegroundColor Green

#--- Exclusions (serveurs avec IP statique) ---
Write-Host "[6/8] Configuration des exclusions..." -ForegroundColor Yellow
Add-DhcpServerv4ExclusionRange -ScopeId $ScopeID -StartRange "10.3.100.1" -EndRange "10.3.100.9"
Write-Host "    Exclusion: 10.3.100.1 - 10.3.100.9 (serveurs)" -ForegroundColor Green
Add-DhcpServerv4ExclusionRange -ScopeId $ScopeID -StartRange "10.3.100.250" -EndRange "10.3.100.254"
Write-Host "    Exclusion: 10.3.100.250 - 10.3.100.254 (équipements réseau)" -ForegroundColor Green

#--- Configuration du DNS dynamique ---
Write-Host "[7/8] Configuration du DNS dynamique (DDNS)..." -ForegroundColor Yellow
Set-DhcpServerv4DnsSetting -ScopeId $ScopeID `
    -DynamicUpdates Always `
    -DeleteDnsRROnLeaseExpiry $true `
    -UpdateDnsRRForOlderClients $true `
    -DnsSuffix $DNSDomain
Write-Host "    DNS dynamique activé" -ForegroundColor Green

#--- Configuration des credentials pour DDNS ---
Write-Host "[8/8] Configuration des credentials DDNS..." -ForegroundColor Yellow
# Le compte de service DHCP doit avoir les droits de mise à jour DNS
$DhcpDnsCredential = Get-Credential -Message "Entrez les credentials pour les mises à jour DDNS (rem\Administrator)"
Set-DhcpServerDnsCredential -Credential $DhcpDnsCredential -ComputerName "remdcsrv.rem.wsl2025.org"
Write-Host "    Credentials DDNS configurés" -ForegroundColor Green

#--- Vérification ---
Write-Host "`n=== Vérification de la configuration DHCP ===" -ForegroundColor Cyan
Get-DhcpServerv4Scope -ScopeId $ScopeID | Format-Table -AutoSize
Get-DhcpServerv4OptionValue -ScopeId $ScopeID | Format-Table -AutoSize

Write-Host "`n=== Configuration DHCP terminée ===" -ForegroundColor Green
Write-Host "Ensuite, exécutez le script 05-Configure-AD-Structure.ps1" -ForegroundColor Yellow
