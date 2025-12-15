#############################################################################
# REMDCSRV - Configuration DHCP Failover (Serveur Principal)
# Site: Remote (WorldSkills France)
# Ce script crée la relation de failover avec REMINFRASRV
#############################################################################

# Variables
$PartnerServer = "reminfrasrv.rem.wsl2025.org"
$ScopeID = "10.3.100.0"
$FailoverName = "REM_DHCP_Failover"
$SharedSecret = "P@ssw0rd"

Write-Host "=== Configuration DHCP Failover sur REMDCSRV ===" -ForegroundColor Cyan
Write-Host "    Partenaire: $PartnerServer" -ForegroundColor Yellow

#--- Vérification de la connectivité au partenaire ---
Write-Host "[1/3] Vérification de la connectivité au partenaire..." -ForegroundColor Yellow
if (!(Test-Connection -ComputerName "10.3.100.2" -Count 2 -Quiet)) {
    Write-Host "ERREUR: Impossible de joindre le partenaire DHCP (10.3.100.2)" -ForegroundColor Red
    Write-Host "Assurez-vous que REMINFRASRV est configuré et accessible." -ForegroundColor Red
    exit 1
}
Write-Host "    Connectivité OK vers $PartnerServer" -ForegroundColor Green

#--- Vérification du scope local ---
Write-Host "[2/3] Vérification du scope DHCP local..." -ForegroundColor Yellow
$localScope = Get-DhcpServerv4Scope -ScopeId $ScopeID -ErrorAction SilentlyContinue
if (!$localScope) {
    Write-Host "ERREUR: Le scope $ScopeID n'existe pas sur ce serveur" -ForegroundColor Red
    Write-Host "Exécutez d'abord le script 04-Configure-DHCP.ps1" -ForegroundColor Red
    exit 1
}
Write-Host "    Scope trouvé: $ScopeID" -ForegroundColor Green

#--- Configuration du Failover ---
Write-Host "[3/3] Création de la relation de failover..." -ForegroundColor Yellow

# Vérifier si le failover existe déjà
$existingFailover = Get-DhcpServerv4Failover -Name $FailoverName -ErrorAction SilentlyContinue

if ($existingFailover) {
    Write-Host "    Relation de failover existe déjà" -ForegroundColor Yellow
    Write-Host "    État actuel:" -ForegroundColor Cyan
    $existingFailover | Format-List Name, State, Mode, PartnerServer
} else {
    try {
        # Créer la relation de failover en mode Load Balance (50/50)
        Add-DhcpServerv4Failover -Name $FailoverName `
            -PartnerServer $PartnerServer `
            -ScopeId $ScopeID `
            -LoadBalancePercent 50 `
            -SharedSecret $SharedSecret `
            -AutoStateTransition $true `
            -MaxClientLeadTime "01:00:00" `
            -StateSwitchInterval "00:30:00" `
            -Force
        
        Write-Host "    Relation de failover créée avec succès!" -ForegroundColor Green
        Write-Host "    Mode: Load Balance 50/50" -ForegroundColor Cyan
    } catch {
        Write-Host "ERREUR: Impossible de créer le failover: $_" -ForegroundColor Red
        exit 1
    }
}

#--- Vérification finale ---
Write-Host "`n=== Vérification de la configuration Failover ===" -ForegroundColor Cyan
Get-DhcpServerv4Failover -Name $FailoverName | Format-List *

Write-Host "`n=== Configuration DHCP Failover terminée ===" -ForegroundColor Green
Write-Host "`nLe scope $ScopeID est maintenant en haute disponibilité." -ForegroundColor Yellow
Write-Host "Les deux serveurs (REMDCSRV et REMINFRASRV) peuvent attribuer des adresses IP." -ForegroundColor Yellow
