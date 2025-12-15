#############################################################################
# REMCLT - Script de test de connectivité complète
# Site: Remote (WorldSkills France)
#############################################################################

Write-Host "=== Test de connectivité REMCLT ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

#############################################################################
# Test 1: Connectivité réseau de base
#############################################################################

Write-Host "=== 1. Connectivité réseau de base ===" -ForegroundColor Yellow

$NetworkTests = @(
    @{Name="Gateway locale (REMFW)"; Target="10.3.100.254"; Description="Passerelle du site Remote"},
    @{Name="REMDCSRV"; Target="10.3.100.1"; Description="Contrôleur de domaine Remote"},
    @{Name="REMINFRASRV"; Target="10.3.100.2"; Description="Serveur infrastructure Remote"},
    @{Name="WANRTR"; Target="10.116.3.1"; Description="Routeur WAN"},
    @{Name="HQDCSRV"; Target="10.3.10.1"; Description="Contrôleur de domaine HQ"},
    @{Name="HQINFRASRV"; Target="10.3.10.3"; Description="Serveur infrastructure HQ"},
    @{Name="Internet DNS"; Target="8.8.3.1"; Description="Serveur DNS Internet"}
)

foreach ($test in $NetworkTests) {
    $result = Test-Connection -ComputerName $test.Target -Count 2 -Quiet
    $latency = ""
    if ($result) {
        $ping = Test-Connection -ComputerName $test.Target -Count 1
        $latency = "($($ping.ResponseTime)ms)"
    }
    
    $status = if ($result) { "✓ OK $latency" } else { "✗ ÉCHEC" }
    $color = if ($result) { "Green" } else { "Red" }
    
    Write-Host "  $($test.Name.PadRight(25)) : " -NoNewline
    Write-Host $status -ForegroundColor $color
}

#############################################################################
# Test 2: Résolution DNS
#############################################################################

Write-Host "`n=== 2. Résolution DNS ===" -ForegroundColor Yellow

$DNSTests = @(
    "remdcsrv.rem.wsl2025.org",
    "reminfrasrv.rem.wsl2025.org",
    "hqdcsrv.hq.wsl2025.org",
    "hqinfrasrv.wsl2025.org",
    "www.wsl2025.org",
    "vpn.wsl2025.org",
    "webmail.wsl2025.org"
)

foreach ($fqdn in $DNSTests) {
    try {
        $resolved = Resolve-DnsName -Name $fqdn -Type A -ErrorAction Stop | Select-Object -First 1
        Write-Host "  $($fqdn.PadRight(35)) : " -NoNewline
        Write-Host "✓ $($resolved.IPAddress)" -ForegroundColor Green
    } catch {
        Write-Host "  $($fqdn.PadRight(35)) : " -NoNewline
        Write-Host "✗ Non résolu" -ForegroundColor Red
    }
}

#############################################################################
# Test 3: Services Active Directory
#############################################################################

Write-Host "`n=== 3. Services Active Directory ===" -ForegroundColor Yellow

# Test LDAP
$ldapTest = Test-NetConnection -ComputerName "10.3.100.1" -Port 389 -WarningAction SilentlyContinue
Write-Host "  LDAP (389)                        : " -NoNewline
if ($ldapTest.TcpTestSucceeded) { Write-Host "✓ OK" -ForegroundColor Green } else { Write-Host "✗ ÉCHEC" -ForegroundColor Red }

# Test Kerberos
$kerbTest = Test-NetConnection -ComputerName "10.3.100.1" -Port 88 -WarningAction SilentlyContinue
Write-Host "  Kerberos (88)                     : " -NoNewline
if ($kerbTest.TcpTestSucceeded) { Write-Host "✓ OK" -ForegroundColor Green } else { Write-Host "✗ ÉCHEC" -ForegroundColor Red }

# Test Global Catalog
$gcTest = Test-NetConnection -ComputerName "10.3.100.1" -Port 3268 -WarningAction SilentlyContinue
Write-Host "  Global Catalog (3268)             : " -NoNewline
if ($gcTest.TcpTestSucceeded) { Write-Host "✓ OK" -ForegroundColor Green } else { Write-Host "✗ ÉCHEC" -ForegroundColor Red }

#############################################################################
# Test 4: Partages réseau
#############################################################################

Write-Host "`n=== 4. Partages réseau ===" -ForegroundColor Yellow

$Shares = @(
    "\\rem.wsl2025.org\users",
    "\\rem.wsl2025.org\Department",
    "\\reminfrasrv.rem.wsl2025.org\users",
    "\\reminfrasrv.rem.wsl2025.org\Department"
)

foreach ($share in $Shares) {
    $accessible = Test-Path $share -ErrorAction SilentlyContinue
    Write-Host "  $($share.PadRight(45)) : " -NoNewline
    if ($accessible) { Write-Host "✓ Accessible" -ForegroundColor Green } else { Write-Host "✗ Non accessible" -ForegroundColor Red }
}

#############################################################################
# Test 5: Accès Internet
#############################################################################

Write-Host "`n=== 5. Accès Internet ===" -ForegroundColor Yellow

# Test HTTP vers le serveur web HQ
$webTest = Test-NetConnection -ComputerName "217.3.160.1" -Port 443 -WarningAction SilentlyContinue
Write-Host "  HTTPS www.wsl2025.org (443)       : " -NoNewline
if ($webTest.TcpTestSucceeded) { Write-Host "✓ OK" -ForegroundColor Green } else { Write-Host "✗ ÉCHEC" -ForegroundColor Red }

# Test vers serveur Internet
$inetTest = Test-NetConnection -ComputerName "8.8.3.2" -Port 80 -WarningAction SilentlyContinue
Write-Host "  HTTP inetsrv.worldskills.org (80) : " -NoNewline
if ($inetTest.TcpTestSucceeded) { Write-Host "✓ OK" -ForegroundColor Green } else { Write-Host "✗ ÉCHEC" -ForegroundColor Red }

#############################################################################
# Test 6: Services HQ (via MAN)
#############################################################################

Write-Host "`n=== 6. Services HQ (via MAN) ===" -ForegroundColor Yellow

# Test SMB vers HQ
$smbHQ = Test-NetConnection -ComputerName "10.3.10.1" -Port 445 -WarningAction SilentlyContinue
Write-Host "  SMB vers HQDCSRV (445)            : " -NoNewline
if ($smbHQ.TcpTestSucceeded) { Write-Host "✓ OK" -ForegroundColor Green } else { Write-Host "✗ ÉCHEC" -ForegroundColor Red }

# Test RDP vers HQ Web Server
$rdpHQ = Test-NetConnection -ComputerName "10.3.30.1" -Port 3389 -WarningAction SilentlyContinue
Write-Host "  RDP vers HQWEBSRV (3389)          : " -NoNewline
if ($rdpHQ.TcpTestSucceeded) { Write-Host "✓ OK" -ForegroundColor Green } else { Write-Host "✗ ÉCHEC" -ForegroundColor Red }

#############################################################################
# Résumé de la configuration
#############################################################################

Write-Host "`n=== Configuration actuelle ===" -ForegroundColor Cyan

Write-Host "`nNom de l'ordinateur: $env:COMPUTERNAME" -ForegroundColor White
Write-Host "Domaine: $((Get-WmiObject Win32_ComputerSystem).Domain)" -ForegroundColor White

Write-Host "`nConfiguration IP:" -ForegroundColor White
Get-NetIPConfiguration | Where-Object { $_.IPv4Address } | ForEach-Object {
    Write-Host "  Interface: $($_.InterfaceAlias)"
    Write-Host "  IP: $($_.IPv4Address.IPAddress)/$($_.IPv4Address.PrefixLength)"
    Write-Host "  Gateway: $($_.IPv4DefaultGateway.NextHop)"
    Write-Host "  DNS: $($_.DNSServer.ServerAddresses -join ', ')"
}

Write-Host "`n=== Fin des tests ===" -ForegroundColor Cyan
