# 🏢 Site Remote - WorldSkills Lyon 2025

Configuration complète du site distant (Remote) pour l'infrastructure WSL2025.

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Plan d'adressage IP](#plan-dadressage-ip)
4. [Ordre de déploiement](#ordre-de-déploiement)
5. [Configuration détaillée par serveur](#configuration-détaillée-par-serveur)
6. [Vérification et tests](#vérification-et-tests)
7. [Troubleshooting](#troubleshooting)

---

## 🌐 Vue d'ensemble

Le site Remote héberge les bureaux de **WorldSkills France (WSFR)** et est connecté au site HQ (WSL2025) via une connexion **MAN privée**.

### Composants

| Équipement | Rôle | OS/Plateforme | IP |
|------------|------|---------------|-----|
| **REMFW** | Routeur/Firewall | Cisco CSR1000v | 10.3.100.254 (LAN) / 10.116.3.2 (MAN) |
| **REMDCSRV** | Contrôleur de domaine principal | Windows Server 2022 | 10.3.100.1 |
| **REMINFRASRV** | Serveur d'infrastructure | Windows Server 2022 | 10.3.100.2 |
| **REMCLT** | Client utilisateur | Windows 11 | DHCP |

### Services déployés

- ✅ Active Directory (domaine enfant `rem.wsl2025.org`)
- ✅ DNS avec DNSSEC
- ✅ DHCP avec failover et DNS dynamique
- ✅ DFS Namespace et Replication
- ✅ Partages de fichiers avec quotas
- ✅ GPO (administration locale IT, blocage panneau de config, etc.)
- ✅ Routage OSPF vers le site HQ
- ✅ Firewall ACL

---

## 🏗️ Architecture

```
                        INTERNET
                            │
                       [WANRTR]
                      /         \
                VRF INET      VRF MAN
                   /              \
             [EDGE1/2]        10.116.3.0/30
                 │                  │
            Site HQ            [REMFW]
         10.3.10.0/26         10.3.100.254
                                    │
                            ────────┼────────
                            │       │       │
                            │       │       │
                      REMDCSRV  REMINFRASRV  REMCLT
                      10.3.100.1  10.3.100.2  DHCP
```

### Flux réseau

```
REMCLT ──→ REMFW ──→ WANRTR ──→ EDGE1/2 ──→ HQ Site
                         │
                         └──→ Internet (via NAT sur EDGE)
```

---

## 📊 Plan d'adressage IP

### Réseau Remote (10.3.100.0/24)

| Fonction | IP | Description |
|----------|-----|-------------|
| REMDCSRV | 10.3.100.1 | DC principal |
| REMINFRASRV | 10.3.100.2 | Serveur infra |
| Réservé serveurs | 10.3.100.3-9 | Expansion future |
| DHCP Range | 10.3.100.10-200 | Clients |
| Réservé réseau | 10.3.100.250-253 | Équipements |
| REMFW (Gateway) | 10.3.100.254 | Passerelle |

### Lien MAN (10.116.3.0/30)

| Équipement | IP |
|------------|-----|
| WANRTR | 10.116.3.1 |
| REMFW | 10.116.3.2 |

---

## 📝 Ordre de déploiement

### Phase 1: Infrastructure réseau

```
1. REMFW     → Configuration du routeur/firewall
```

### Phase 2: Contrôleur de domaine (REMDCSRV)

```
2. REMDCSRV  → 01-Basic-Config.ps1       (Config de base + IP)
             → [REDÉMARRAGE]
3. REMDCSRV  → 02-Install-ADDS.ps1       (Installation AD DS)
             → [REDÉMARRAGE AUTOMATIQUE]
4. REMDCSRV  → 03-Configure-DNS.ps1      (Configuration DNS + DNSSEC)
5. REMDCSRV  → 04-Configure-DHCP.ps1     (Configuration DHCP)
6. REMDCSRV  → 05-Configure-AD-Structure.ps1 (OU, Groupes, Users)
7. REMDCSRV  → 06-Configure-GPO.ps1      (Stratégies de groupe)
```

### Phase 3: Serveur d'infrastructure (REMINFRASRV)

```
8. REMINFRASRV  → 01-Basic-Config.ps1    (Config de base + IP)
                → [REDÉMARRAGE]
9. REMINFRASRV  → 02-Join-Domain.ps1     (Jonction au domaine)
                → [REDÉMARRAGE]
10. REMINFRASRV → 03-Install-Roles.ps1   (Installation des rôles)
11. REMINFRASRV → 04-Configure-DNS.ps1   (DNS secondaire)
12. REMINFRASRV → 05-Configure-DHCP-Failover.ps1 (DHCP failover)
13. REMINFRASRV → 06-Configure-DFS.ps1   (DFS + Partages)
```

### Phase 4: Finalisation DHCP Failover

```
14. REMDCSRV → 07-Configure-DHCP-Failover.ps1 (Création relation failover)
```

### Phase 5: Client (REMCLT)

```
15. REMCLT   → Configure-REMCLT.ps1      (DHCP + Jonction domaine)
             → [REDÉMARRAGE]
16. REMCLT   → Test-Connectivity.ps1     (Vérification)
```

---

## ⚙️ Configuration détaillée par serveur

### REMFW (Cisco CSR1000v)

**Fichier:** `REMFW/remfw-config.ios`

| Paramètre | Valeur |
|-----------|--------|
| Hostname | REMFW |
| Domaine DNS | wsl2025.org |
| Enable Secret | P@ssw0rd |
| SSH User | admin / P@ssw0rd |
| Interface LAN | Gi1 - 10.3.100.254/24 |
| Interface MAN | Gi2 - 10.116.3.2/30 |
| OSPF Area | 0 |
| OSPF Auth | MD5 (P@ssw0rd) |

**Fonctionnalités:**
- Routage OSPF vers WANRTR
- NAT/PAT pour accès Internet
- ACL de filtrage (services autorisés uniquement)
- EEM pour auto-recovery de l'interface MAN

---

### REMDCSRV (Windows Server 2022)

**Dossier:** `REMDCSRV/`

| Paramètre | Valeur |
|-----------|--------|
| Hostname | REMDCSRV |
| IP | 10.3.100.1/24 |
| Domaine | rem.wsl2025.org |
| Forêt parent | wsl2025.org |
| Rôles | AD DS, DNS, DHCP |

**Active Directory:**
- Domaine enfant de wsl2025.org
- Catalogue Global
- DNSSEC activé

**DHCP Scope:**
- Réseau: 10.3.100.0/24
- Plage: 10.3.100.10 - 10.3.100.200
- Bail: 2 heures
- Options: DNS, Gateway, NTP, Domaine
- DNS Dynamique: Activé

**Utilisateurs créés:**
| Nom | Login | Groupe | Email |
|-----|-------|--------|-------|
| Ela STIQUE | estique | Warehouse | estique@wsl2025.org |
| Rachid TAHA | rtaha | Direction | rtaha@wsl2025.org |
| Denis PELTIER | dpeltier | IT | dpeltier@wsl2025.org |

---

### REMINFRASRV (Windows Server 2022)

**Dossier:** `REMINFRASRV/`

| Paramètre | Valeur |
|-----------|--------|
| Hostname | REMINFRASRV |
| IP | 10.3.100.2/24 |
| Domaine | rem.wsl2025.org (membre) |
| Rôles | DNS, DHCP, DFS, File Server |

**Partages:**

| Partage | Chemin local | Lecteur | Description |
|---------|--------------|---------|-------------|
| users | C:\shares\datausers | U: | Home drives (quota 20Mo) |
| Department | C:\shares\Department | S: | Dossiers départementaux |

**DFS Namespace:**
- `\\rem.wsl2025.org\users`
- `\\rem.wsl2025.org\Department`

---

### REMCLT (Windows 11)

**Dossier:** `REMCLT/`

| Paramètre | Valeur |
|-----------|--------|
| IP | DHCP |
| Domaine | rem.wsl2025.org |
| OU | OU=Computers,OU=Remote |

**Lecteurs mappés (via GPO):**
- U: → Home drive personnel
- S: → Dossier département

---

## ✅ Vérification et tests

### Sur REMFW

```cisco
show ip interface brief
show ip route
show ip ospf neighbor
show ip nat translations
show access-lists
```

### Sur REMDCSRV

```powershell
# DNS
nslookup remdcsrv.rem.wsl2025.org
Get-DnsServerZone

# DHCP
Get-DhcpServerv4Scope
Get-DhcpServerv4Lease -ScopeId 10.3.100.0

# AD
Get-ADDomain
Get-ADUser -Filter * -SearchBase "OU=Workers,OU=Remote,DC=rem,DC=wsl2025,DC=org"
```

### Sur REMINFRASRV

```powershell
# DHCP Failover
Get-DhcpServerv4Failover

# DFS
Get-DfsnRoot
Get-DfsnFolder -Path "\\rem.wsl2025.org\*"

# Partages
Get-SmbShare
```

### Sur REMCLT

```powershell
# Exécuter le script de test
.\Test-Connectivity.ps1

# Tests manuels
ipconfig /all
nslookup www.wsl2025.org
Test-Connection 10.3.10.1
net use
```

---

## 🔧 Troubleshooting

### Problèmes courants

| Problème | Solution |
|----------|----------|
| DHCP ne distribue pas d'IP | Vérifier autorisation AD: `Get-DhcpServerInDC` |
| DNS ne résout pas | Vérifier forwarder: `Get-DnsServerForwarder` |
| Pas d'accès Internet | Vérifier OSPF sur REMFW: `show ip ospf neighbor` |
| Partages inaccessibles | Vérifier permissions NTFS et SMB |
| GPO non appliquées | `gpupdate /force` puis `gpresult /r` |

### Commandes de diagnostic

```powershell
# Réplication AD
repadmin /replsummary

# DNS
dcdiag /test:dns

# Événements
Get-EventLog -LogName System -Newest 50 | Where-Object {$_.EntryType -eq "Error"}
```

---

## 📁 Structure des fichiers

```
remote-site/
├── README.md                          # Ce fichier
├── REMFW/
│   └── remfw-config.ios               # Configuration Cisco
├── REMDCSRV/
│   ├── 01-Basic-Config.ps1            # Configuration de base
│   ├── 02-Install-ADDS.ps1            # Installation AD DS
│   ├── 03-Configure-DNS.ps1           # Configuration DNS
│   ├── 04-Configure-DHCP.ps1          # Configuration DHCP
│   ├── 05-Configure-AD-Structure.ps1  # OU, Groupes, Users
│   ├── 06-Configure-GPO.ps1           # Stratégies de groupe
│   └── 07-Configure-DHCP-Failover.ps1 # Failover DHCP
├── REMINFRASRV/
│   ├── 01-Basic-Config.ps1            # Configuration de base
│   ├── 02-Join-Domain.ps1             # Jonction au domaine
│   ├── 03-Install-Roles.ps1           # Installation des rôles
│   ├── 04-Configure-DNS.ps1           # DNS secondaire
│   ├── 05-Configure-DHCP-Failover.ps1 # DHCP failover (partenaire)
│   └── 06-Configure-DFS.ps1           # DFS + Partages
├── REMCLT/
│   ├── Configure-REMCLT.ps1           # Configuration client
│   └── Test-Connectivity.ps1          # Tests de connectivité
└── documentation/
    └── (diagrammes additionnels)
```

---

## 📞 Support

- **Mot de passe par défaut:** `P@ssw0rd`
- **Domaine:** `rem.wsl2025.org`
- **Forêt racine:** `wsl2025.org`

---

*WorldSkills Lyon 2025 - SAE 501*
