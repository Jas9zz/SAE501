# Plan d'adressage IP - Site Remote

## Réseau principal: 10.3.100.0/24

### Allocation des adresses

```
10.3.100.0/24 (256 adresses - 254 utilisables)
├── 10.3.100.0          Adresse réseau
├── 10.3.100.1          REMDCSRV (DC)
├── 10.3.100.2          REMINFRASRV (Infra)
├── 10.3.100.3-9        Réservé serveurs futurs (7 adresses)
├── 10.3.100.10-200     Plage DHCP clients (191 adresses)
├── 10.3.100.201-249    Réservé expansion (49 adresses)
├── 10.3.100.250-253    Équipements réseau (4 adresses)
├── 10.3.100.254        REMFW (Gateway)
└── 10.3.100.255        Broadcast
```

### Détail par fonction

#### Serveurs (10.3.100.1-9)
| IP | Hostname | Fonction |
|----|----------|----------|
| 10.3.100.1 | REMDCSRV | Contrôleur de domaine, DNS, DHCP |
| 10.3.100.2 | REMINFRASRV | DNS, DHCP failover, DFS |
| 10.3.100.3-9 | (réservé) | Serveurs futurs |

#### Clients DHCP (10.3.100.10-200)
- **Plage:** 10.3.100.10 - 10.3.100.200
- **Capacité:** 191 adresses
- **Requis:** 80 clients (selon cahier des charges)
- **Marge:** 111 adresses supplémentaires

#### Équipements réseau (10.3.100.250-254)
| IP | Équipement | Fonction |
|----|------------|----------|
| 10.3.100.254 | REMFW | Gateway / Firewall |

---

## Lien MAN: 10.116.3.0/30

```
10.116.3.0/30 (4 adresses - 2 utilisables)
├── 10.116.3.0          Adresse réseau
├── 10.116.3.1          WANRTR (côté Remote)
├── 10.116.3.2          REMFW (côté WAN)
└── 10.116.3.3          Broadcast
```

---

## Configuration DHCP

### Scope Remote_Clients

```
Scope ID:       10.3.100.0
Subnet Mask:    255.255.255.0 (/24)
Start Range:    10.3.100.10
End Range:      10.3.100.200
Lease Duration: 2 heures
```

### Options DHCP

| Option | Valeur | Description |
|--------|--------|-------------|
| 003 | 10.3.100.254 | Default Gateway (REMFW) |
| 006 | 10.3.100.1 | DNS Server (REMDCSRV) |
| 015 | rem.wsl2025.org | DNS Domain Name |
| 042 | 10.3.10.3 | NTP Server (HQINFRASRV) |

### Exclusions

| Plage | Raison |
|-------|--------|
| 10.3.100.1-9 | Serveurs avec IP statique |
| 10.3.100.250-254 | Équipements réseau |

---

## Récapitulatif

| Paramètre | Valeur |
|-----------|--------|
| Réseau | 10.3.100.0/24 |
| Masque | 255.255.255.0 |
| Gateway | 10.3.100.254 |
| DNS primaire | 10.3.100.1 |
| DNS secondaire | 10.3.100.2 |
| Broadcast | 10.3.100.255 |
| Adresses utilisables | 254 |
| Serveurs prévus | 10 max |
| Clients prévus | 80 max |
