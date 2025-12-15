#############################################################################
# REMINFRASRV - Configuration DFS
# Site: Remote (WorldSkills France)
# DFS Namespace: \\rem.wsl2025.org\...
#############################################################################

# Variables
$DomainName = "rem.wsl2025.org"
$ServerName = "REMINFRASRV"
$SharesPath = "C:\shares"

Write-Host "=== Configuration DFS sur REMINFRASRV ===" -ForegroundColor Cyan

#--- Vérification des rôles DFS ---
Write-Host "[1/7] Vérification des rôles DFS..." -ForegroundColor Yellow
$dfsNamespace = (Get-WindowsFeature -Name FS-DFS-Namespace).Installed
$dfsReplication = (Get-WindowsFeature -Name FS-DFS-Replication).Installed

if (!$dfsNamespace -or !$dfsReplication) {
    Write-Host "ERREUR: Les rôles DFS ne sont pas installés" -ForegroundColor Red
    exit 1
}
Write-Host "    DFS Namespace et Replication installés" -ForegroundColor Green

#--- Création de la structure de dossiers ---
Write-Host "[2/7] Création de la structure de dossiers..." -ForegroundColor Yellow

$Folders = @(
    "$SharesPath",
    "$SharesPath\datausers",
    "$SharesPath\Department",
    "$SharesPath\Department\IT",
    "$SharesPath\Department\Direction",
    "$SharesPath\Department\Warehouse"
)

foreach ($folder in $Folders) {
    if (!(Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-Host "    Dossier créé: $folder" -ForegroundColor Green
    } else {
        Write-Host "    Dossier existe: $folder" -ForegroundColor Yellow
    }
}

#--- Création du partage Users (Home Drives) ---
Write-Host "[3/7] Création du partage Users (Home Drives)..." -ForegroundColor Yellow

$UsersShareName = "users"
$UsersSharePath = "$SharesPath\datausers"

# Supprimer le partage existant si présent
Remove-SmbShare -Name $UsersShareName -Force -ErrorAction SilentlyContinue

# Créer le nouveau partage
New-SmbShare -Name $UsersShareName `
    -Path $UsersSharePath `
    -FullAccess "REM\Domain Admins" `
    -ChangeAccess "REM\Domain Users" `
    -Description "Home Drives pour les utilisateurs Remote"

Write-Host "    Partage créé: \\$ServerName\$UsersShareName" -ForegroundColor Green

# Configurer les permissions NTFS pour ABE (Access-Based Enumeration)
$acl = Get-Acl $UsersSharePath

# Activer ABE sur le partage
Set-SmbShare -Name $UsersShareName -FolderEnumerationMode AccessBased

Write-Host "    ABE activé (les utilisateurs ne voient que leur dossier)" -ForegroundColor Green

#--- Configuration du quota pour Users ---
Write-Host "[4/7] Configuration du quota (20 Mo par utilisateur)..." -ForegroundColor Yellow

# Créer un modèle de quota
$QuotaTemplate = "REM_UserQuota_20MB"
try {
    New-FsrmQuotaTemplate -Name $QuotaTemplate `
        -Size 20MB `
        -SoftLimit:$false `
        -Description "Quota 20 Mo pour les dossiers utilisateurs" `
        -ErrorAction Stop
    Write-Host "    Modèle de quota créé: $QuotaTemplate" -ForegroundColor Green
} catch {
    Write-Host "    Modèle de quota existe déjà ou erreur" -ForegroundColor Yellow
}

# Appliquer le quota auto au dossier users
try {
    New-FsrmAutoQuota -Path $UsersSharePath -Template $QuotaTemplate -ErrorAction Stop
    Write-Host "    Quota automatique appliqué à $UsersSharePath" -ForegroundColor Green
} catch {
    Write-Host "    Quota auto existe déjà ou erreur" -ForegroundColor Yellow
}

#--- Création du partage Department ---
Write-Host "[5/7] Création du partage Department..." -ForegroundColor Yellow

$DeptShareName = "Department"
$DeptSharePath = "$SharesPath\Department"

# Supprimer le partage existant si présent
Remove-SmbShare -Name $DeptShareName -Force -ErrorAction SilentlyContinue

# Créer le nouveau partage
New-SmbShare -Name $DeptShareName `
    -Path $DeptSharePath `
    -FullAccess "REM\Domain Admins" `
    -ReadAccess "REM\Domain Users" `
    -Description "Dossiers départementaux Remote"

# Activer ABE
Set-SmbShare -Name $DeptShareName -FolderEnumerationMode AccessBased

Write-Host "    Partage créé: \\$ServerName\$DeptShareName" -ForegroundColor Green

# Configurer les permissions NTFS par département
$Departments = @(
    @{Name="IT"; Group="GG_REM_IT"},
    @{Name="Direction"; Group="GG_REM_Direction"},
    @{Name="Warehouse"; Group="GG_REM_Warehouse"}
)

foreach ($dept in $Departments) {
    $deptPath = "$DeptSharePath\$($dept.Name)"
    
    # Configurer les ACL NTFS
    $acl = Get-Acl $deptPath
    $acl.SetAccessRuleProtection($true, $false)  # Désactiver l'héritage
    
    # Administrateurs - Full Control
    $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "REM\Domain Admins", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($adminRule)
    
    # Groupe du département - Modify
    $deptRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "REM\$($dept.Group)", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($deptRule)
    
    Set-Acl -Path $deptPath -AclObject $acl
    Write-Host "    Permissions configurées pour $($dept.Name)" -ForegroundColor Green
}

#--- Création du DFS Namespace ---
Write-Host "[6/7] Création du DFS Namespace de domaine..." -ForegroundColor Yellow

# Créer la racine DFS de domaine (si elle n'existe pas)
$DFSRoot = "\\$DomainName\shares"

try {
    # Vérifier si le namespace existe
    $existingRoot = Get-DfsnRoot -Path $DFSRoot -ErrorAction SilentlyContinue
    
    if (!$existingRoot) {
        # Créer le namespace de domaine
        New-DfsnRoot -Path $DFSRoot `
            -TargetPath "\\$ServerName.$DomainName\shares" `
            -Type DomainV2 `
            -Description "Namespace DFS Remote Site"
        Write-Host "    DFS Root créé: $DFSRoot" -ForegroundColor Green
    } else {
        Write-Host "    DFS Root existe déjà: $DFSRoot" -ForegroundColor Yellow
    }
} catch {
    Write-Host "    Erreur création DFS Root: $_" -ForegroundColor Red
    Write-Host "    Création manuelle requise via DFS Management" -ForegroundColor Yellow
}

# Créer les dossiers DFS
$DFSFolders = @(
    @{Path="$DFSRoot\users"; Target="\\$ServerName.$DomainName\users"},
    @{Path="$DFSRoot\Department"; Target="\\$ServerName.$DomainName\Department"}
)

foreach ($dfs in $DFSFolders) {
    try {
        New-DfsnFolder -Path $dfs.Path -TargetPath $dfs.Target -ErrorAction Stop
        Write-Host "    DFS Folder créé: $($dfs.Path)" -ForegroundColor Green
    } catch {
        Write-Host "    DFS Folder existe ou erreur: $($dfs.Path)" -ForegroundColor Yellow
    }
}

#--- Script pour créer les dossiers home automatiquement ---
Write-Host "[7/7] Création du script de provisioning des home folders..." -ForegroundColor Yellow

$ProvisionScript = @'
# Script de provisioning des dossiers home utilisateurs
# À exécuter périodiquement ou lors de la création d'un utilisateur

$UsersPath = "C:\shares\datausers"
$DomainUsers = Get-ADUser -Filter * -SearchBase "OU=Workers,OU=Remote,DC=rem,DC=wsl2025,DC=org"

foreach ($user in $DomainUsers) {
    $userFolder = Join-Path $UsersPath $user.SamAccountName
    
    if (!(Test-Path $userFolder)) {
        # Créer le dossier
        New-Item -ItemType Directory -Path $userFolder -Force | Out-Null
        
        # Configurer les permissions
        $acl = Get-Acl $userFolder
        $acl.SetAccessRuleProtection($true, $false)
        
        # Administrateurs - Full Control
        $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "REM\Domain Admins", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($adminRule)
        
        # Utilisateur - Modify
        $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $user.SamAccountName, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($userRule)
        
        Set-Acl -Path $userFolder -AclObject $acl
        Write-Host "Dossier créé pour: $($user.SamAccountName)"
    }
}
'@

$ProvisionScript | Out-File -FilePath "C:\Scripts\Provision-HomeFolders.ps1" -Encoding UTF8 -Force
New-Item -ItemType Directory -Path "C:\Scripts" -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "    Script de provisioning créé: C:\Scripts\Provision-HomeFolders.ps1" -ForegroundColor Green

#--- Vérification ---
Write-Host "`n=== Vérification de la configuration ===" -ForegroundColor Cyan

Write-Host "`nPartages SMB:" -ForegroundColor Yellow
Get-SmbShare | Where-Object { $_.Name -notlike "*$" } | Format-Table Name, Path, Description -AutoSize

Write-Host "DFS Namespaces:" -ForegroundColor Yellow
Get-DfsnRoot -ErrorAction SilentlyContinue | Format-Table Path, State -AutoSize
Get-DfsnFolder -Path "$DFSRoot\*" -ErrorAction SilentlyContinue | Format-Table Path, State -AutoSize

Write-Host "`n=== Configuration DFS terminée ===" -ForegroundColor Green
Write-Host "`nRécapitulatif des partages:" -ForegroundColor Cyan
Write-Host "  - Home Drives: \\rem.wsl2025.org\users (Lecteur U:)" -ForegroundColor White
Write-Host "  - Department: \\rem.wsl2025.org\Department (Lecteur S:)" -ForegroundColor White
Write-Host "`nN'oubliez pas d'exécuter C:\Scripts\Provision-HomeFolders.ps1 pour créer les dossiers home" -ForegroundColor Yellow
