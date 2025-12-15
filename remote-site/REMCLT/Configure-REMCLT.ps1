#############################################################################
# REMCLT - Configuration du client Windows 11
# Site: Remote (WorldSkills France)
# Rôle: Client utilisateur MAN
#############################################################################

# Variables
$DomainName = "rem.wsl2025.org"

Write-Host "=== Configuration de REMCLT ===" -ForegroundColor Cyan

#############################################################################
# ÉTAPE 1: Configuration réseau (DHCP)
#############################################################################

Write-Host "[1/5] Configuration réseau (DHCP)..." -ForegroundColor Yellow

# Identifier l'interface réseau
$Interface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1

if ($Interface) {
    # Activer DHCP
    Set-NetIPInterface -InterfaceIndex $Interface.ifIndex -Dhcp Enabled
    Set-DnsClientServerAddress -InterfaceIndex $Interface.ifIndex -ResetServerAddresses
    
    # Renouveler l'adresse IP
    ipconfig /release
    Start-Sleep -Seconds 2
    ipconfig /renew
    
    Write-Host "    DHCP activé sur $($Interface.Name)" -ForegroundColor Green
} else {
    Write-Host "    ATTENTION: Aucune interface réseau active trouvée" -ForegroundColor Red
}

#############################################################################
# ÉTAPE 2: Jonction au domaine
#############################################################################

Write-Host "[2/5] Jonction au domaine $DomainName..." -ForegroundColor Yellow

# Vérifier si déjà dans le domaine
$currentDomain = (Get-WmiObject Win32_ComputerSystem).Domain

if ($currentDomain -eq $DomainName) {
    Write-Host "    Déjà membre du domaine $DomainName" -ForegroundColor Green
} else {
    Write-Host "    Entrez les credentials d'un administrateur du domaine" -ForegroundColor Yellow
    $Credential = Get-Credential -Message "Credentials pour joindre $DomainName (ex: rem\Administrator)"
    
    try {
        Add-Computer -DomainName $DomainName `
            -OUPath "OU=Computers,OU=Remote,DC=rem,DC=wsl2025,DC=org" `
            -Credential $Credential `
            -Restart:$false `
            -Force
        
        Write-Host "    Jonction au domaine réussie!" -ForegroundColor Green
        $NeedRestart = $true
    } catch {
        Write-Host "    ERREUR: $_" -ForegroundColor Red
    }
}

#############################################################################
# ÉTAPE 3: Vérification de la connectivité
#############################################################################

Write-Host "[3/5] Vérification de la connectivité..." -ForegroundColor Yellow

$TestTargets = @(
    @{Name="Gateway (REMFW)"; IP="10.3.100.254"},
    @{Name="DC (REMDCSRV)"; IP="10.3.100.1"},
    @{Name="Infra (REMINFRASRV)"; IP="10.3.100.2"},
    @{Name="HQ DC"; IP="10.3.10.1"},
    @{Name="Internet (DNS)"; IP="8.8.3.1"}
)

foreach ($target in $TestTargets) {
    $result = Test-Connection -ComputerName $target.IP -Count 1 -Quiet
    if ($result) {
        Write-Host "    ✓ $($target.Name) ($($target.IP))" -ForegroundColor Green
    } else {
        Write-Host "    ✗ $($target.Name) ($($target.IP))" -ForegroundColor Red
    }
}

#############################################################################
# ÉTAPE 4: Test de résolution DNS
#############################################################################

Write-Host "[4/5] Test de résolution DNS..." -ForegroundColor Yellow

$DNSTests = @(
    "remdcsrv.rem.wsl2025.org",
    "reminfrasrv.rem.wsl2025.org",
    "hqdcsrv.hq.wsl2025.org",
    "www.wsl2025.org"
)

foreach ($fqdn in $DNSTests) {
    try {
        $resolved = Resolve-DnsName -Name $fqdn -ErrorAction Stop
        Write-Host "    ✓ $fqdn -> $($resolved.IPAddress)" -ForegroundColor Green
    } catch {
        Write-Host "    ✗ $fqdn (échec)" -ForegroundColor Red
    }
}

#############################################################################
# ÉTAPE 5: Test des partages réseau
#############################################################################

Write-Host "[5/5] Test des partages réseau..." -ForegroundColor Yellow

$Shares = @(
    "\\rem.wsl2025.org\users",
    "\\rem.wsl2025.org\Department"
)

foreach ($share in $Shares) {
    if (Test-Path $share -ErrorAction SilentlyContinue) {
        Write-Host "    ✓ $share accessible" -ForegroundColor Green
    } else {
        Write-Host "    ✗ $share non accessible" -ForegroundColor Yellow
    }
}

#############################################################################
# Résumé
#############################################################################

Write-Host "`n=== Configuration terminée ===" -ForegroundColor Green

# Afficher la configuration IP
Write-Host "`nConfiguration IP actuelle:" -ForegroundColor Cyan
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } | 
    Select-Object InterfaceAlias, IPAddress, PrefixLength | Format-Table -AutoSize

Write-Host "Serveurs DNS:" -ForegroundColor Cyan
Get-DnsClientServerAddress -AddressFamily IPv4 | 
    Where-Object { $_.ServerAddresses } | 
    Select-Object InterfaceAlias, ServerAddresses | Format-Table -AutoSize

if ($NeedRestart) {
    Write-Host "`nREDÉMARRAGE NÉCESSAIRE pour finaliser la jonction au domaine!" -ForegroundColor Red
    $restart = Read-Host "Voulez-vous redémarrer maintenant? (O/N)"
    if ($restart -eq "O" -or $restart -eq "o") {
        Restart-Computer -Force
    }
}

Write-Host "`nAprès connexion avec un compte du domaine:" -ForegroundColor Yellow
Write-Host "  - Les lecteurs réseau seront mappés automatiquement (GPO)" -ForegroundColor White
Write-Host "  - U: -> Dossier personnel" -ForegroundColor White
Write-Host "  - S: -> Dossier département" -ForegroundColor White
