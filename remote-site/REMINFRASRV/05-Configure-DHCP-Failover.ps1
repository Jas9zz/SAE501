#############################################################################
# REMINFRASRV - Configuration DHCP Failover
# Site: Remote (WorldSkills France)
# Partenaire: REMDCSRV (10.3.100.1)
#############################################################################

# Variables
$PartnerServer = "remdcsrv.rem.wsl2025.org"
$PartnerIP = "10.3.100.1"
$LocalServer = "reminfrasrv.rem.wsl2025.org"
$LocalIP = "10.3.100.2"
$ScopeID = "10.3.100.0"
$FailoverName = "REM_DHCP_Failover"
$SharedSecret = "P@ssw0rd"

Write-Host "=== Configuration DHCP Failover sur REMINFRASRV ===" -ForegroundColor Cyan

#--- Vérification que le rôle DHCP est installé ---
Write-Host "[1/5] Vérification du rôle DHCP..." -ForegroundColor Yellow
if (!(Get-WindowsFeature -Name DHCP).Installed) {
    Write-Host "ERREUR: Le rôle DHCP n'est pas installé" -ForegroundColor Red
    exit 1
}
Write-Host "    Rôle DHCP installé" -ForegroundColor Green

#--- Autorisation DHCP dans AD ---
Write-Host "[2/5] Autorisation du serveur DHCP dans AD..." -ForegroundColor Yellow
try {
    Add-DhcpServerInDC -DnsName $LocalServer -IPAddress $LocalIP
    Write-Host "    Serveur DHCP autorisé dans AD" -ForegroundColor Green
} catch {
    Write-Host "    Serveur déjà autorisé ou erreur: $_" -ForegroundColor Yellow
}

# Supprimer le flag de configuration
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12" -Name "ConfigurationState" -Value 2 -ErrorAction SilentlyContinue

#--- Vérification de la connectivité au partenaire ---
Write-Host "[3/5] Vérification de la connectivité au partenaire..." -ForegroundColor Yellow
if (!(Test-Connection -ComputerName $PartnerIP -Count 2 -Quiet)) {
    Write-Host "ERREUR: Impossible de joindre le partenaire DHCP ($PartnerIP)" -ForegroundColor Red
    exit 1
}
Write-Host "    Connectivité OK vers $PartnerServer" -ForegroundColor Green

#--- Configuration du Failover ---
Write-Host "[4/5] Configuration de la relation de failover..." -ForegroundColor Yellow

# Vérifier si le failover existe déjà
$existingFailover = Get-DhcpServerv4Failover -Name $FailoverName -ErrorAction SilentlyContinue

if ($existingFailover) {
    Write-Host "    Relation de failover existe déjà" -ForegroundColor Yellow
} else {
    # Le failover doit être configuré depuis le serveur principal (REMDCSRV)
    # Ici on vérifie juste que le scope existe sur le partenaire
    
    Write-Host "    ATTENTION: Le failover doit être configuré depuis REMDCSRV" -ForegroundColor Yellow
    Write-Host "    Exécutez le script suivant sur REMDCSRV:" -ForegroundColor Yellow
    
    $FailoverScript = @"

# Script à exécuter sur REMDCSRV pour configurer le failover
Add-DhcpServerv4Failover -Name "$FailoverName" ``
    -PartnerServer "$LocalServer" ``
    -ScopeId $ScopeID ``
    -LoadBalancePercent 50 ``
    -SharedSecret "$SharedSecret" ``
    -AutoStateTransition `$true ``
    -MaxClientLeadTime "01:00:00" ``
    -StateSwitchInterval "00:30:00" ``
    -Force

"@
    Write-Host $FailoverScript -ForegroundColor Cyan
}

#--- Vérification des scopes répliqués ---
Write-Host "[5/5] Vérification de la réplication des scopes..." -ForegroundColor Yellow

# Attendre la réplication
Start-Sleep -Seconds 5

$localScope = Get-DhcpServerv4Scope -ScopeId $ScopeID -ErrorAction SilentlyContinue
if ($localScope) {
    Write-Host "    Scope répliqué: $ScopeID" -ForegroundColor Green
    Write-Host "    État: $($localScope.State)" -ForegroundColor Cyan
} else {
    Write-Host "    Scope non encore répliqué. Vérifiez après configuration du failover sur REMDCSRV" -ForegroundColor Yellow
}

#--- Affichage du script pour REMDCSRV ---
Write-Host "`n=== Script à exécuter sur REMDCSRV ===" -ForegroundColor Magenta
Write-Host @"
#--- Exécuter sur REMDCSRV pour créer le failover ---
Add-DhcpServerv4Failover -Name "$FailoverName" `
    -PartnerServer "$LocalServer" `
    -ScopeId $ScopeID `
    -LoadBalancePercent 50 `
    -SharedSecret "$SharedSecret" `
    -AutoStateTransition `$true `
    -MaxClientLeadTime "01:00:00" `
    -StateSwitchInterval "00:30:00" `
    -Force

# Vérification
Get-DhcpServerv4Failover -Name "$FailoverName"
"@ -ForegroundColor Yellow

Write-Host "`n=== Configuration DHCP Failover terminée ===" -ForegroundColor Green
Write-Host "Exécutez maintenant le script 06-Configure-DFS.ps1" -ForegroundColor Yellow
