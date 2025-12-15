# Checklist de déploiement - Site Remote

## Prérequis

- [ ] Site HQ opérationnel (DCWSL, HQDCSRV, HQINFRASRV)
- [ ] Connectivité MAN établie (WANRTR configuré)
- [ ] Images ISO Windows Server 2022 et Windows 11 disponibles
- [ ] Accès aux hyperviseurs (VMware/Proxmox)

---

## Phase 1: REMFW (Routeur/Firewall)

### Configuration
- [ ] Créer la VM CSR1000v
- [ ] Configurer les interfaces (LAN + MAN)
- [ ] Appliquer la configuration `remfw-config.ios`

### Vérification
- [ ] `show ip interface brief` - Interfaces UP
- [ ] `show ip ospf neighbor` - Voisinage OSPF avec WANRTR
- [ ] `ping 10.116.3.1` - Connectivité vers WANRTR
- [ ] `ping 10.3.10.1` - Connectivité vers HQ (via OSPF)

---

## Phase 2: REMDCSRV (Contrôleur de domaine)

### Installation OS
- [ ] Créer la VM Windows Server 2022
- [ ] Installer Windows Server 2022 (Desktop Experience)
- [ ] Configurer IP statique: 10.3.100.1/24

### Scripts à exécuter
- [ ] `01-Basic-Config.ps1` → Redémarrer
- [ ] `02-Install-ADDS.ps1` → Redémarrage auto
- [ ] `03-Configure-DNS.ps1`
- [ ] `04-Configure-DHCP.ps1`
- [ ] `05-Configure-AD-Structure.ps1`
- [ ] `06-Configure-GPO.ps1`

### Vérification
- [ ] `Get-ADDomain` - Domaine rem.wsl2025.org créé
- [ ] `Get-DnsServerZone` - Zone DNS active
- [ ] `Get-DhcpServerv4Scope` - Scope DHCP actif
- [ ] `Get-ADUser -Filter *` - Utilisateurs créés
- [ ] `Get-GPO -All` - GPOs créées

---

## Phase 3: REMINFRASRV (Serveur d'infrastructure)

### Installation OS
- [ ] Créer la VM Windows Server 2022
- [ ] Installer Windows Server 2022 (Desktop Experience)
- [ ] Configurer IP statique: 10.3.100.2/24

### Scripts à exécuter
- [ ] `01-Basic-Config.ps1` → Redémarrer
- [ ] `02-Join-Domain.ps1` → Redémarrer
- [ ] `03-Install-Roles.ps1`
- [ ] `04-Configure-DNS.ps1`
- [ ] `05-Configure-DHCP-Failover.ps1`
- [ ] `06-Configure-DFS.ps1`

### Vérification
- [ ] `(Get-WmiObject Win32_ComputerSystem).Domain` = rem.wsl2025.org
- [ ] `Get-WindowsFeature | Where Installed` - Rôles installés
- [ ] `Get-SmbShare` - Partages créés
- [ ] `Get-DfsnRoot` - DFS Namespace actif

---

## Phase 4: Finalisation DHCP Failover

### Sur REMDCSRV
- [ ] Exécuter `07-Configure-DHCP-Failover.ps1`

### Vérification
- [ ] `Get-DhcpServerv4Failover` - Relation active
- [ ] Sur REMINFRASRV: `Get-DhcpServerv4Scope` - Scope répliqué

---

## Phase 5: REMCLT (Client Windows 11)

### Installation OS
- [ ] Créer la VM Windows 11
- [ ] Installer Windows 11

### Scripts à exécuter
- [ ] `Configure-REMCLT.ps1` → Redémarrer
- [ ] `Test-Connectivity.ps1`

### Vérification
- [ ] IP obtenue par DHCP
- [ ] Membre du domaine rem.wsl2025.org
- [ ] Résolution DNS fonctionnelle
- [ ] Accès aux partages réseau
- [ ] Accès Internet

---

## Phase 6: Tests finaux

### Connectivité
- [ ] REMCLT → REMDCSRV (ping)
- [ ] REMCLT → REMINFRASRV (ping)
- [ ] REMCLT → HQDCSRV (ping via MAN)
- [ ] REMCLT → Internet (ping 8.8.3.1)

### Services
- [ ] Authentification AD (connexion utilisateur)
- [ ] Partage users accessible
- [ ] Partage Department accessible
- [ ] Lecteurs mappés (U: et S:)
- [ ] GPO appliquées

### Haute disponibilité
- [ ] Arrêter REMDCSRV → DHCP via REMINFRASRV fonctionne
- [ ] Redémarrer REMDCSRV → Failover restauré

---

## Notes post-déploiement

### Étapes manuelles requises

1. **GPO REM_IT_LocalAdmins:**
   - Ouvrir GPMC
   - Configurer Restricted Groups
   - Ajouter REM\GG_REM_IT → Administrators

2. **GPO REM_MapDrives:**
   - Ouvrir GPMC
   - Configurer Drive Maps:
     - S: → \\rem.wsl2025.org\Department
     - U: → \\rem.wsl2025.org\users\%username%

3. **GPO REM_DeployCertificates:**
   - Importer WSFR-ROOT-CA.cer (Root CA)
   - Importer WSFR-SUB-CA.cer (Sub CA)

### Documentation à conserver

- [ ] Captures d'écran des configurations
- [ ] Export des GPO
- [ ] Backup des configurations switches/routeurs
- [ ] Liste des comptes créés

---

## Contacts

| Rôle | Contact |
|------|---------|
| Admin réseau | admin@wsl2025.org |
| Support IT | dpeltier@wsl2025.org |

---

*Date de création: [À compléter]*
*Dernière mise à jour: [À compléter]*
