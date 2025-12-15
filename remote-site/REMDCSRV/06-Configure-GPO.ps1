#############################################################################
# REMDCSRV - Configuration des GPO
# Site: Remote (WorldSkills France)
# Domaine: rem.wsl2025.org
#############################################################################

# Variables
$DomainDN = "DC=rem,DC=wsl2025,DC=org"
$DomainName = "rem.wsl2025.org"
$RemoteOU = "OU=Remote,$DomainDN"

Write-Host "=== Configuration des GPO pour le site Remote ===" -ForegroundColor Cyan

#--- Import du module GroupPolicy ---
Import-Module GroupPolicy
Import-Module ActiveDirectory

#############################################################################
# GPO 1: IT Group = Local Administrators
#############################################################################

Write-Host "[1/5] Création GPO: REM_IT_LocalAdmins..." -ForegroundColor Yellow

$GPOName1 = "REM_IT_LocalAdmins"
$GPO1 = Get-GPO -Name $GPOName1 -ErrorAction SilentlyContinue

if (!$GPO1) {
    $GPO1 = New-GPO -Name $GPOName1 -Comment "Membres du groupe IT sont administrateurs locaux"
    Write-Host "    GPO créée: $GPOName1" -ForegroundColor Green
} else {
    Write-Host "    GPO existe déjà: $GPOName1" -ForegroundColor Yellow
}

# Configuration via Restricted Groups (Groupes restreints)
# Cette configuration ajoute GG_REM_IT au groupe local Administrators
$GPOPath = "\\$DomainName\SYSVOL\$DomainName\Policies\{$($GPO1.Id)}\Machine\Microsoft\Windows NT\SecEdit"

# Créer le fichier GptTmpl.inf pour les groupes restreints
$GptTmplContent = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Group Membership]
*S-1-5-32-544__Members = *S-1-5-21-DOMAIN-512,REM\GG_REM_IT
"@

# Note: La configuration complète des Restricted Groups nécessite 
# une modification manuelle via GPMC ou l'utilisation de scripts LGPO
Write-Host "    ATTENTION: Configurez manuellement les Restricted Groups via GPMC" -ForegroundColor Yellow
Write-Host "    Ajoutez REM\GG_REM_IT au groupe local Administrators" -ForegroundColor Yellow

# Lier la GPO à l'OU Remote
New-GPLink -Name $GPOName1 -Target $RemoteOU -LinkEnabled Yes -ErrorAction SilentlyContinue
Write-Host "    GPO liée à: $RemoteOU" -ForegroundColor Green

#############################################################################
# GPO 2: Block Control Panel (except IT)
#############################################################################

Write-Host "[2/5] Création GPO: REM_BlockControlPanel..." -ForegroundColor Yellow

$GPOName2 = "REM_BlockControlPanel"
$GPO2 = Get-GPO -Name $GPOName2 -ErrorAction SilentlyContinue

if (!$GPO2) {
    $GPO2 = New-GPO -Name $GPOName2 -Comment "Bloquer le Panneau de configuration sauf pour IT"
    Write-Host "    GPO créée: $GPOName2" -ForegroundColor Green
} else {
    Write-Host "    GPO existe déjà: $GPOName2" -ForegroundColor Yellow
}

# Bloquer l'accès au Panneau de configuration
# User Configuration > Administrative Templates > Control Panel > Prohibit access to Control Panel and PC settings
Set-GPRegistryValue -Name $GPOName2 -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoControlPanel" -Type DWord -Value 1

Write-Host "    Panneau de configuration bloqué" -ForegroundColor Green

# Lier la GPO
New-GPLink -Name $GPOName2 -Target $RemoteOU -LinkEnabled Yes -ErrorAction SilentlyContinue
Write-Host "    GPO liée à: $RemoteOU" -ForegroundColor Green

# Configurer le filtrage de sécurité pour exclure IT
# Retirer "Authenticated Users" et ajouter "DL_REM_Users" mais pas "GG_REM_IT"
Set-GPPermission -Name $GPOName2 -TargetName "Authenticated Users" -TargetType Group -PermissionLevel None -Replace
Set-GPPermission -Name $GPOName2 -TargetName "DL_REM_Users" -TargetType Group -PermissionLevel GpoApply
Set-GPPermission -Name $GPOName2 -TargetName "GG_REM_IT" -TargetType Group -PermissionLevel GpoRead  # Deny Apply
Write-Host "    Filtrage: IT exclu de cette GPO" -ForegroundColor Green

#############################################################################
# GPO 3: Map Network Drives (Department & Public)
#############################################################################

Write-Host "[3/5] Création GPO: REM_MapDrives..." -ForegroundColor Yellow

$GPOName3 = "REM_MapDrives"
$GPO3 = Get-GPO -Name $GPOName3 -ErrorAction SilentlyContinue

if (!$GPO3) {
    $GPO3 = New-GPO -Name $GPOName3 -Comment "Mappage des lecteurs réseau Department et Public"
    Write-Host "    GPO créée: $GPOName3" -ForegroundColor Green
} else {
    Write-Host "    GPO existe déjà: $GPOName3" -ForegroundColor Yellow
}

# Les Drive Maps sont configurés via Group Policy Preferences
# User Configuration > Preferences > Windows Settings > Drive Maps
Write-Host "    ATTENTION: Configurez manuellement les Drive Maps via GPMC:" -ForegroundColor Yellow
Write-Host "      - Lecteur S: -> \\rem.wsl2025.org\Department" -ForegroundColor Cyan
Write-Host "      - Lecteur U: -> \\rem.wsl2025.org\users\%username%" -ForegroundColor Cyan

# Lier la GPO
New-GPLink -Name $GPOName3 -Target $RemoteOU -LinkEnabled Yes -ErrorAction SilentlyContinue
Write-Host "    GPO liée à: $RemoteOU" -ForegroundColor Green

#############################################################################
# GPO 4: Deploy Root CA and Sub CA Certificates
#############################################################################

Write-Host "[4/5] Création GPO: REM_DeployCertificates..." -ForegroundColor Yellow

$GPOName4 = "REM_DeployCertificates"
$GPO4 = Get-GPO -Name $GPOName4 -ErrorAction SilentlyContinue

if (!$GPO4) {
    $GPO4 = New-GPO -Name $GPOName4 -Comment "Déploiement des certificats Root CA et Sub CA"
    Write-Host "    GPO créée: $GPOName4" -ForegroundColor Green
} else {
    Write-Host "    GPO existe déjà: $GPOName4" -ForegroundColor Yellow
}

Write-Host "    ATTENTION: Importez manuellement les certificats via GPMC:" -ForegroundColor Yellow
Write-Host "      Computer Configuration > Policies > Windows Settings > Security Settings > Public Key Policies" -ForegroundColor Cyan
Write-Host "      - Trusted Root Certification Authorities: WSFR-ROOT-CA.cer" -ForegroundColor Cyan
Write-Host "      - Intermediate Certification Authorities: WSFR-SUB-CA.cer" -ForegroundColor Cyan

# Lier la GPO
New-GPLink -Name $GPOName4 -Target $RemoteOU -LinkEnabled Yes -ErrorAction SilentlyContinue
Write-Host "    GPO liée à: $RemoteOU" -ForegroundColor Green

#############################################################################
# GPO 5: Computer Configuration (optionnel)
#############################################################################

Write-Host "[5/5] Création GPO: REM_ComputerConfig..." -ForegroundColor Yellow

$GPOName5 = "REM_ComputerConfig"
$GPO5 = Get-GPO -Name $GPOName5 -ErrorAction SilentlyContinue

if (!$GPO5) {
    $GPO5 = New-GPO -Name $GPOName5 -Comment "Configuration générale des ordinateurs Remote"
    Write-Host "    GPO créée: $GPOName5" -ForegroundColor Green
} else {
    Write-Host "    GPO existe déjà: $GPOName5" -ForegroundColor Yellow
}

# Configuration NTP vers HQINFRASRV
Set-GPRegistryValue -Name $GPOName5 -Key "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -ValueName "NtpServer" -Type String -Value "10.3.10.3,0x9"
Set-GPRegistryValue -Name $GPOName5 -Key "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -ValueName "Type" -Type String -Value "NTP"

Write-Host "    NTP configuré vers HQINFRASRV (10.3.10.3)" -ForegroundColor Green

# Lier la GPO à l'OU Computers
$ComputersOU = "OU=Computers,OU=Remote,$DomainDN"
New-GPLink -Name $GPOName5 -Target $ComputersOU -LinkEnabled Yes -ErrorAction SilentlyContinue
Write-Host "    GPO liée à: $ComputersOU" -ForegroundColor Green

#############################################################################
# Résumé
#############################################################################

Write-Host "`n=== Configuration GPO terminée ===" -ForegroundColor Green
Write-Host "`nGPOs créées et liées à $RemoteOU :" -ForegroundColor Cyan
Get-GPO -All | Where-Object { $_.DisplayName -like "REM_*" } | Select-Object DisplayName, CreationTime | Format-Table -AutoSize

Write-Host "`nÉtapes manuelles requises:" -ForegroundColor Yellow
Write-Host "1. GPMC > $GPOName1 : Configurer Restricted Groups (IT -> Administrators)" -ForegroundColor White
Write-Host "2. GPMC > $GPOName3 : Configurer Drive Maps (S: et U:)" -ForegroundColor White
Write-Host "3. GPMC > $GPOName4 : Importer les certificats Root CA et Sub CA" -ForegroundColor White
Write-Host "`nExécutez 'gpupdate /force' sur les clients pour appliquer les GPO" -ForegroundColor Yellow
