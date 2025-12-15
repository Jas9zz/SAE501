#############################################################################
# REMINFRASRV - Jonction au domaine
# Site: Remote (WorldSkills France)
# Domaine: rem.wsl2025.org
#############################################################################

# Variables
$DomainName = "rem.wsl2025.org"
$OUPath = "OU=Computers,OU=Remote,DC=rem,DC=wsl2025,DC=org"

Write-Host "=== Jonction au domaine $DomainName ===" -ForegroundColor Cyan

#--- Vérification de la connectivité au DC ---
Write-Host "[1/3] Vérification de la connectivité au DC..." -ForegroundColor Yellow
$DCAddress = "10.3.100.1"
if (!(Test-Connection -ComputerName $DCAddress -Count 2 -Quiet)) {
    Write-Host "ERREUR: Impossible de joindre le DC ($DCAddress)" -ForegroundColor Red
    Write-Host "Vérifiez la connectivité réseau et réessayez." -ForegroundColor Red
    exit 1
}
Write-Host "    Connectivité OK vers $DCAddress" -ForegroundColor Green

#--- Vérification DNS ---
Write-Host "[2/3] Vérification de la résolution DNS..." -ForegroundColor Yellow
try {
    $resolved = Resolve-DnsName -Name "remdcsrv.$DomainName" -ErrorAction Stop
    Write-Host "    DNS OK: remdcsrv.$DomainName -> $($resolved.IPAddress)" -ForegroundColor Green
} catch {
    Write-Host "ERREUR: Résolution DNS échouée pour remdcsrv.$DomainName" -ForegroundColor Red
    Write-Host "Vérifiez la configuration DNS et réessayez." -ForegroundColor Red
    exit 1
}

#--- Jonction au domaine ---
Write-Host "[3/3] Jonction au domaine..." -ForegroundColor Yellow
Write-Host "    Entrez les credentials d'un administrateur du domaine" -ForegroundColor Yellow

$Credential = Get-Credential -Message "Credentials pour joindre le domaine $DomainName (ex: rem\Administrator)"

try {
    Add-Computer -DomainName $DomainName `
        -OUPath $OUPath `
        -Credential $Credential `
        -Restart:$false `
        -Force
    
    Write-Host "`n=== Jonction au domaine réussie ===" -ForegroundColor Green
    Write-Host "Le serveur va redémarrer pour finaliser la jonction." -ForegroundColor Yellow
    Write-Host "Après le redémarrage, exécutez le script 03-Install-Roles.ps1" -ForegroundColor Yellow
    
    $restart = Read-Host "Voulez-vous redémarrer maintenant? (O/N)"
    if ($restart -eq "O" -or $restart -eq "o") {
        Restart-Computer -Force
    }
} catch {
    Write-Host "ERREUR: Jonction au domaine échouée: $_" -ForegroundColor Red
    exit 1
}
