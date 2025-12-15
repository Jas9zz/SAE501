#############################################################################
# REMDCSRV - Configuration DNS
# Site: Remote (WorldSkills France)
# Zone: rem.wsl2025.org
#############################################################################

# Variables
$DomainName = "rem.wsl2025.org"
$ParentDomain = "wsl2025.org"
$ForwarderIP = "10.3.10.1"  # DCWSL pour les requêtes wsl2025.org
$DNSSECKeyPath = "C:\DNSSEC"

Write-Host "=== Configuration DNS pour $DomainName ===" -ForegroundColor Cyan

#--- Vérification que le rôle DNS est installé ---
Write-Host "[1/6] Vérification du rôle DNS..." -ForegroundColor Yellow
if (!(Get-WindowsFeature -Name DNS).Installed) {
    Write-Host "    Installation du rôle DNS..." -ForegroundColor Yellow
    Install-WindowsFeature -Name DNS -IncludeManagementTools
}
Write-Host "    Rôle DNS installé" -ForegroundColor Green

#--- Configuration du forwarder ---
Write-Host "[2/6] Configuration du forwarder DNS..." -ForegroundColor Yellow
# Supprimer les forwarders existants
Get-DnsServerForwarder | ForEach-Object { Remove-DnsServerForwarder -IPAddress $_.IPAddress -Force }
# Ajouter le forwarder vers le domaine parent
Add-DnsServerForwarder -IPAddress $ForwarderIP -PassThru
Write-Host "    Forwarder configuré vers $ForwarderIP" -ForegroundColor Green

#--- Configuration de la zone de recherche inversée ---
Write-Host "[3/6] Création de la zone de recherche inversée..." -ForegroundColor Yellow
$ReverseZone = "100.3.10.in-addr.arpa"
if (!(Get-DnsServerZone -Name $ReverseZone -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -NetworkId "10.3.100.0/24" -ReplicationScope Domain
    Write-Host "    Zone inversée créée: $ReverseZone" -ForegroundColor Green
} else {
    Write-Host "    Zone inversée existe déjà" -ForegroundColor Yellow
}

#--- Création des enregistrements DNS ---
Write-Host "[4/6] Création des enregistrements DNS..." -ForegroundColor Yellow

# Enregistrements A
$DNSRecords = @(
    @{Name="remdcsrv"; IP="10.3.100.1"; Type="A"},
    @{Name="reminfrasrv"; IP="10.3.100.2"; Type="A"},
    @{Name="remfw"; IP="10.3.100.254"; Type="A"}
)

foreach ($record in $DNSRecords) {
    try {
        Add-DnsServerResourceRecordA -ZoneName $DomainName -Name $record.Name -IPv4Address $record.IP -CreatePtr -ErrorAction Stop
        Write-Host "    Enregistrement A créé: $($record.Name).$DomainName -> $($record.IP)" -ForegroundColor Green
    } catch {
        Write-Host "    Enregistrement existe déjà ou erreur: $($record.Name)" -ForegroundColor Yellow
    }
}

#--- Activation de la mise à jour dynamique sécurisée ---
Write-Host "[5/6] Activation des mises à jour dynamiques sécurisées..." -ForegroundColor Yellow
Set-DnsServerPrimaryZone -Name $DomainName -DynamicUpdate Secure
Set-DnsServerPrimaryZone -Name $ReverseZone -DynamicUpdate Secure
Write-Host "    Mises à jour dynamiques sécurisées activées" -ForegroundColor Green

#--- Configuration DNSSEC ---
Write-Host "[6/6] Configuration DNSSEC..." -ForegroundColor Yellow

# Créer le dossier pour les clés DNSSEC
if (!(Test-Path $DNSSECKeyPath)) {
    New-Item -ItemType Directory -Path $DNSSECKeyPath -Force | Out-Null
}

# Signer la zone avec DNSSEC
try {
    # Générer les clés KSK et ZSK
    $ZoneName = $DomainName
    
    # Invoke DNSSEC signing
    Invoke-DnsServerZoneSign -ZoneName $ZoneName -SignWithDefault -Force
    
    Write-Host "    Zone $ZoneName signée avec DNSSEC" -ForegroundColor Green
    
    # Configurer les paramètres DNSSEC
    $DnsSecSettings = Get-DnsServerDnsSecZoneSetting -ZoneName $ZoneName
    Write-Host "    Paramètres DNSSEC appliqués" -ForegroundColor Green
    
} catch {
    Write-Host "    ATTENTION: Configuration DNSSEC manuelle requise" -ForegroundColor Yellow
    Write-Host "    Utilisez la console DNS Manager pour signer la zone" -ForegroundColor Yellow
    Write-Host "    Erreur: $_" -ForegroundColor Red
}

Write-Host "`n=== Configuration DNS terminée ===" -ForegroundColor Green
Write-Host "Vérifiez la résolution DNS avec: nslookup remdcsrv.rem.wsl2025.org" -ForegroundColor Yellow
Write-Host "Ensuite, exécutez le script 04-Configure-DHCP.ps1" -ForegroundColor Yellow
