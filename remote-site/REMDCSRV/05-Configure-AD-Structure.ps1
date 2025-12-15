#############################################################################
# REMDCSRV - Configuration Structure Active Directory
# Site: Remote (WorldSkills France)
# Domaine: rem.wsl2025.org
#############################################################################

# Variables
$DomainDN = "DC=rem,DC=wsl2025,DC=org"
$DomainName = "rem.wsl2025.org"
$DefaultPassword = ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force

Write-Host "=== Configuration de la structure Active Directory ===" -ForegroundColor Cyan

#--- Import du module AD ---
Import-Module ActiveDirectory

#############################################################################
# CRÉATION DES ORGANIZATIONAL UNITS
#############################################################################

Write-Host "[1/4] Création des Organizational Units..." -ForegroundColor Yellow

$OUs = @(
    @{Name="Remote"; Path=$DomainDN; Description="Site Remote"},
    @{Name="Workers"; Path="OU=Remote,$DomainDN"; Description="Utilisateurs du site Remote"},
    @{Name="Computers"; Path="OU=Remote,$DomainDN"; Description="Ordinateurs du site Remote"},
    @{Name="Groups"; Path="OU=Remote,$DomainDN"; Description="Groupes du site Remote"}
)

foreach ($ou in $OUs) {
    try {
        if (!(Get-ADOrganizationalUnit -Filter "Name -eq '$($ou.Name)'" -SearchBase $ou.Path -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $ou.Name -Path $ou.Path -Description $ou.Description -ProtectedFromAccidentalDeletion $true
            Write-Host "    OU créée: $($ou.Name)" -ForegroundColor Green
        } else {
            Write-Host "    OU existe déjà: $($ou.Name)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    Erreur création OU $($ou.Name): $_" -ForegroundColor Red
    }
}

#############################################################################
# CRÉATION DES GROUPES
#############################################################################

Write-Host "[2/4] Création des groupes..." -ForegroundColor Yellow

$GroupsPath = "OU=Groups,OU=Remote,$DomainDN"

$Groups = @(
    @{Name="GG_REM_IT"; Scope="Global"; Category="Security"; Description="Groupe global IT Remote"},
    @{Name="GG_REM_Direction"; Scope="Global"; Category="Security"; Description="Groupe global Direction Remote"},
    @{Name="GG_REM_Warehouse"; Scope="Global"; Category="Security"; Description="Groupe global Warehouse Remote"},
    @{Name="DL_REM_Admins"; Scope="DomainLocal"; Category="Security"; Description="Admins locaux Remote"},
    @{Name="DL_REM_Users"; Scope="DomainLocal"; Category="Security"; Description="Utilisateurs Remote"}
)

foreach ($group in $Groups) {
    try {
        if (!(Get-ADGroup -Filter "Name -eq '$($group.Name)'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $group.Name `
                -Path $GroupsPath `
                -GroupScope $group.Scope `
                -GroupCategory $group.Category `
                -Description $group.Description
            Write-Host "    Groupe créé: $($group.Name)" -ForegroundColor Green
        } else {
            Write-Host "    Groupe existe déjà: $($group.Name)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    Erreur création groupe $($group.Name): $_" -ForegroundColor Red
    }
}

#############################################################################
# CRÉATION DES UTILISATEURS
#############################################################################

Write-Host "[3/4] Création des utilisateurs..." -ForegroundColor Yellow

$UsersPath = "OU=Workers,OU=Remote,$DomainDN"

# Utilisateurs du site Remote selon l'annexe
$Users = @(
    @{
        FirstName="Ela"; LastName="STIQUE"; Login="estique"
        Department="Warehouse"; Group="GG_REM_Warehouse"
        Email="estique@wsl2025.org"
    },
    @{
        FirstName="Rachid"; LastName="TAHA"; Login="rtaha"
        Department="Direction"; Group="GG_REM_Direction"
        Email="rtaha@wsl2025.org"
    },
    @{
        FirstName="Denis"; LastName="PELTIER"; Login="dpeltier"
        Department="IT"; Group="GG_REM_IT"
        Email="dpeltier@wsl2025.org"
    }
)

foreach ($user in $Users) {
    try {
        $SamAccountName = $user.Login
        $UPN = "$($user.Login)@$DomainName"
        $DisplayName = "$($user.FirstName) $($user.LastName)"
        
        if (!(Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction SilentlyContinue)) {
            New-ADUser `
                -Name $DisplayName `
                -GivenName $user.FirstName `
                -Surname $user.LastName `
                -SamAccountName $SamAccountName `
                -UserPrincipalName $UPN `
                -EmailAddress $user.Email `
                -Department $user.Department `
                -Path $UsersPath `
                -AccountPassword $DefaultPassword `
                -Enabled $true `
                -ChangePasswordAtLogon $false `
                -PasswordNeverExpires $true
            
            Write-Host "    Utilisateur créé: $DisplayName ($SamAccountName)" -ForegroundColor Green
            
            # Ajout au groupe
            Add-ADGroupMember -Identity $user.Group -Members $SamAccountName
            Write-Host "      -> Ajouté au groupe: $($user.Group)" -ForegroundColor Cyan
            
            # Ajout au groupe DL_REM_Users
            Add-ADGroupMember -Identity "DL_REM_Users" -Members $SamAccountName
            
            # Si IT, ajouter au groupe DL_REM_Admins
            if ($user.Department -eq "IT") {
                Add-ADGroupMember -Identity "DL_REM_Admins" -Members $SamAccountName
                Write-Host "      -> Ajouté au groupe: DL_REM_Admins (Admin local)" -ForegroundColor Cyan
            }
        } else {
            Write-Host "    Utilisateur existe déjà: $SamAccountName" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    Erreur création utilisateur $($user.Login): $_" -ForegroundColor Red
    }
}

#############################################################################
# MÉTHODE AGDLP - Association des groupes
#############################################################################

Write-Host "[4/4] Configuration AGDLP..." -ForegroundColor Yellow

# Ajouter les groupes globaux aux groupes Domain Local
try {
    Add-ADGroupMember -Identity "DL_REM_Admins" -Members "GG_REM_IT" -ErrorAction SilentlyContinue
    Write-Host "    GG_REM_IT -> DL_REM_Admins" -ForegroundColor Green
} catch {
    Write-Host "    Association GG_REM_IT -> DL_REM_Admins existe déjà" -ForegroundColor Yellow
}

Write-Host "`n=== Structure Active Directory créée ===" -ForegroundColor Green
Write-Host "Ensuite, exécutez le script 06-Configure-GPO.ps1" -ForegroundColor Yellow

#--- Vérification ---
Write-Host "`n=== Vérification ===" -ForegroundColor Cyan
Write-Host "OUs:" -ForegroundColor Yellow
Get-ADOrganizationalUnit -Filter * -SearchBase "OU=Remote,$DomainDN" | Select-Object Name, DistinguishedName | Format-Table -AutoSize

Write-Host "Groupes:" -ForegroundColor Yellow
Get-ADGroup -Filter * -SearchBase "OU=Groups,OU=Remote,$DomainDN" | Select-Object Name, GroupScope | Format-Table -AutoSize

Write-Host "Utilisateurs:" -ForegroundColor Yellow
Get-ADUser -Filter * -SearchBase "OU=Workers,OU=Remote,$DomainDN" | Select-Object Name, SamAccountName, Enabled | Format-Table -AutoSize
