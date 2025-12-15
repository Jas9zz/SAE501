#############################################################################
# REMDCSRV - Configuration de base
# Site: Remote (WorldSkills France)
# OS: Windows Server 2022
# Rôle: Contrôleur de domaine, DNS, DHCP
#############################################################################

# Variables
$Hostname = "REMDCSRV"
$IPAddress = "10.3.100.1"
$PrefixLength = 24
$Gateway = "10.3.100.254"
$DNSServer = "10.3.10.1"  # HQDCSRV temporairement, puis lui-même après promo DC
$InterfaceAlias = "Ethernet0"  # À adapter selon votre VM

Write-Host "=== Configuration de base de REMDCSRV ===" -ForegroundColor Cyan

#--- Renommer l'ordinateur ---
Write-Host "[1/4] Renommage de l'ordinateur en $Hostname..." -ForegroundColor Yellow
if ($env:COMPUTERNAME -ne $Hostname) {
    Rename-Computer -NewName $Hostname -Force
    Write-Host "    Redémarrage nécessaire après cette étape." -ForegroundColor Red
}

#--- Configuration IP statique ---
Write-Host "[2/4] Configuration de l'adresse IP statique..." -ForegroundColor Yellow

# Désactiver DHCP
Set-NetIPInterface -InterfaceAlias $InterfaceAlias -Dhcp Disabled

# Supprimer les anciennes configurations IP
Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false

# Configurer la nouvelle IP
New-NetIPAddress -InterfaceAlias $InterfaceAlias `
    -IPAddress $IPAddress `
    -PrefixLength $PrefixLength `
    -DefaultGateway $Gateway

# Configurer le DNS
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServer

Write-Host "    IP configurée: $IPAddress/$PrefixLength" -ForegroundColor Green
Write-Host "    Gateway: $Gateway" -ForegroundColor Green
Write-Host "    DNS: $DNSServer" -ForegroundColor Green

#--- Configuration du fuseau horaire ---
Write-Host "[3/4] Configuration du fuseau horaire..." -ForegroundColor Yellow
Set-TimeZone -Id "Romance Standard Time"
Write-Host "    Fuseau horaire: Romance Standard Time (Paris)" -ForegroundColor Green

#--- Désactiver le pare-feu temporairement (pour les tests) ---
Write-Host "[4/4] Configuration du pare-feu..." -ForegroundColor Yellow
# Optionnel: désactiver temporairement pour les tests
# Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Autoriser les règles AD, DNS, DHCP
Enable-NetFirewallRule -DisplayGroup "Active Directory Domain Services"
Enable-NetFirewallRule -DisplayGroup "DNS Service"
Enable-NetFirewallRule -DisplayGroup "DHCP Server"
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"

Write-Host "`n=== Configuration de base terminée ===" -ForegroundColor Green
Write-Host "IMPORTANT: Redémarrez le serveur si le nom a été changé" -ForegroundColor Red
Write-Host "Ensuite, exécutez le script 02-Install-ADDS.ps1" -ForegroundColor Yellow

# Redémarrage optionnel
$restart = Read-Host "Voulez-vous redémarrer maintenant? (O/N)"
if ($restart -eq "O" -or $restart -eq "o") {
    Restart-Computer -Force
}
