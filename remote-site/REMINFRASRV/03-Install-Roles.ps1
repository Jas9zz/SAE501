#############################################################################
# REMINFRASRV - Installation des rôles
# Site: Remote (WorldSkills France)
# Rôles: DNS, DHCP, DFS, File Server
#############################################################################

Write-Host "=== Installation des rôles sur REMINFRASRV ===" -ForegroundColor Cyan

#--- Installation du rôle DNS ---
Write-Host "[1/5] Installation du rôle DNS..." -ForegroundColor Yellow
Install-WindowsFeature -Name DNS -IncludeManagementTools
Write-Host "    Rôle DNS installé" -ForegroundColor Green

#--- Installation du rôle DHCP ---
Write-Host "[2/5] Installation du rôle DHCP..." -ForegroundColor Yellow
Install-WindowsFeature -Name DHCP -IncludeManagementTools
Write-Host "    Rôle DHCP installé" -ForegroundColor Green

#--- Installation de DFS ---
Write-Host "[3/5] Installation de DFS (Namespace + Replication)..." -ForegroundColor Yellow
Install-WindowsFeature -Name FS-DFS-Namespace, FS-DFS-Replication -IncludeManagementTools
Write-Host "    DFS Namespace et Replication installés" -ForegroundColor Green

#--- Installation du File Server ---
Write-Host "[4/5] Installation du File Server..." -ForegroundColor Yellow
Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools
Write-Host "    File Server installé" -ForegroundColor Green

#--- Installation de FSRM (File Server Resource Manager) ---
Write-Host "[5/5] Installation de FSRM..." -ForegroundColor Yellow
Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools
Write-Host "    FSRM installé" -ForegroundColor Green

#--- Vérification ---
Write-Host "`n=== Vérification des rôles installés ===" -ForegroundColor Cyan
Get-WindowsFeature | Where-Object {$_.Installed -eq $true -and $_.Name -match "DNS|DHCP|DFS|FS-"} | 
    Select-Object Name, DisplayName, Installed | Format-Table -AutoSize

Write-Host "`n=== Installation des rôles terminée ===" -ForegroundColor Green
Write-Host "Exécutez maintenant les scripts de configuration:" -ForegroundColor Yellow
Write-Host "  - 04-Configure-DNS.ps1" -ForegroundColor Cyan
Write-Host "  - 05-Configure-DHCP-Failover.ps1" -ForegroundColor Cyan
Write-Host "  - 06-Configure-DFS.ps1" -ForegroundColor Cyan
