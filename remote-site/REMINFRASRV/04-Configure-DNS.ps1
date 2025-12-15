#############################################################################
# REMINFRASRV - Configuration DNS Secondaire
# Site: Remote (WorldSkills France)
# Zone: rem.wsl2025.org (secondaire)
#############################################################################

# Variables
$DomainName = "rem.wsl2025.org"
$PrimaryDNS = "10.3.100.1"  # REMDCSRV

Write-Host "=== Configuration DNS Secondaire sur REMINFRASRV ===" -ForegroundColor Cyan

#--- Vérification que le rôle DNS est installé ---
Write-Host "[1/4] Vérification du rôle DNS..." -ForegroundColor Yellow
if (!(Get-WindowsFeature -Name DNS).Installed) {
    Write-Host "ERREUR: Le rôle DNS n'est pas installé" -ForegroundColor Red
    Write-Host "Exécutez d'abord le script 03-Install-Roles.ps1" -ForegroundColor Red
    exit 1
}
Write-Host "    Rôle DNS installé" -ForegroundColor Green

#--- Configuration comme DNS secondaire intégré AD ---
Write-Host "[2/4] Configuration de la zone DNS secondaire..." -ForegroundColor Yellow

# Pour une zone intégrée AD, le DNS sera automatiquement répliqué
# car le serveur est membre du domaine et la zone est stockée dans AD

# Vérifier si la zone existe déjà (réplication AD)
$zone = Get-DnsServerZone -Name $DomainName -ErrorAction SilentlyContinue

if ($zone) {
    Write-Host "    Zone $DomainName existe (réplication AD)" -ForegroundColor Green
} else {
    Write-Host "    Configuration de la zone secondaire..." -ForegroundColor Yellow
    # Si la zone n'est pas intégrée AD, créer une zone secondaire
    Add-DnsServerSecondaryZone -Name $DomainName -ZoneFile "$DomainName.dns" -MasterServers $PrimaryDNS
    Write-Host "    Zone secondaire créée: $DomainName" -ForegroundColor Green
}

#--- Configuration du forwarder ---
Write-Host "[3/4] Configuration du forwarder DNS..." -ForegroundColor Yellow
# Forwarder vers le DC principal
Add-DnsServerForwarder -IPAddress $PrimaryDNS -PassThru -ErrorAction SilentlyContinue
Write-Host "    Forwarder configuré vers $PrimaryDNS" -ForegroundColor Green

#--- Configuration de la zone inversée ---
Write-Host "[4/4] Configuration de la zone inversée..." -ForegroundColor Yellow
$ReverseZone = "100.3.10.in-addr.arpa"

$revZone = Get-DnsServerZone -Name $ReverseZone -ErrorAction SilentlyContinue
if (!$revZone) {
    # Créer zone secondaire inversée
    Add-DnsServerSecondaryZone -Name $ReverseZone -ZoneFile "$ReverseZone.dns" -MasterServers $PrimaryDNS -ErrorAction SilentlyContinue
    Write-Host "    Zone inversée secondaire créée: $ReverseZone" -ForegroundColor Green
} else {
    Write-Host "    Zone inversée existe déjà" -ForegroundColor Yellow
}

#--- Vérification ---
Write-Host "`n=== Vérification de la configuration DNS ===" -ForegroundColor Cyan
Get-DnsServerZone | Select-Object ZoneName, ZoneType, IsDsIntegrated | Format-Table -AutoSize

Write-Host "`n=== Configuration DNS secondaire terminée ===" -ForegroundColor Green
Write-Host "Exécutez maintenant le script 05-Configure-DHCP-Failover.ps1" -ForegroundColor Yellow
