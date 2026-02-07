# Enterprise Multi-Tenant AKS Platform

Infrastructure-as-Code Plattform fuer Multi-Tenant Kubernetes auf Azure.
Neuer Kunde = eine Zeile in `customers.tf` - der Rest passiert automatisch.

## Staging Architektur

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGING ENVIRONMENT                                                         │
│                                                                             │
│  GitHub Actions (Manual Trigger)                                            │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  gh workflow run "Terraform" -f environment=staging -f action=apply   │ │
│  │                                                                        │ │
│  │  Security Scan → Init → Validate → Plan → Apply → GitOps Push        │ │
│  │  Auth: OIDC (keine Passwoerter)                                       │ │
│  └──────────────────────────────────┬─────────────────────────────────────┘ │
│                                     │                                       │
│                                     ▼                                       │
│  Azure (northeurope)                                                        │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ Resource Group: rg-mercury-staging                                     │ │
│  │                                                                        │ │
│  │  AKS: mercury-staging                                                  │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │ System Pool: 1x Standard_D2s_v3 (CriticalAddonsOnly)            │  │ │
│  │  │ User Pool:   1x Standard_D2s_v3 (Workloads)                     │  │ │
│  │  │                                                                  │  │ │
│  │  │ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────────────┐   │  │ │
│  │  │ │ FluxCD   │ │ Traefik  │ │ Cert-Mgr │ │ CNPG Operator     │   │  │ │
│  │  │ │ (GitOps) │ │ (Ingress)│ │ (TLS)    │ │ (PostgreSQL HA)   │   │  │ │
│  │  │ └──────────┘ └──────────┘ └──────────┘ └───────────────────┘   │  │ │
│  │  │                                                                  │  │ │
│  │  │ Pro Kunde:                                                       │  │ │
│  │  │ ┌────────────────────────────────────────────────────────────┐   │  │ │
│  │  │ │ Namespace: cicero                                          │   │  │ │
│  │  │ │ ├─ n8n Deployment (1 Replica)                              │   │  │ │
│  │  │ │ ├─ CNPG PostgreSQL (1 Instance)                            │   │  │ │
│  │  │ │ ├─ SecretProviderClass → Key Vault CSI                     │   │  │ │
│  │  │ │ └─ ScheduledBackup (taeglich 03:00 UTC)                    │   │  │ │
│  │  │ └────────────────────────────────────────────────────────────┘   │  │ │
│  │  │                                                                  │  │ │
│  │  │ Monitoring: Prometheus + Grafana (KeyVault Credentials)         │  │ │
│  │  └──────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                        │ │
│  │  Key Vault: kv-merc-staging-XXXX (RBAC, Secret Rotation)             │ │
│  │  Storage:   mercurybackupsstaging (LRS - lokal redundant)            │ │
│  │                                                                        │ │
│  │  Network: Cilium CNI + Network Policies                               │ │
│  │  Auth:    Azure AD RBAC (kubectl via Device Code Flow)                │ │
│  │  Updates: Automatic Patch Upgrades (Sonntag 02:00 UTC)                │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  Remote State: Azure Blob → phase-11/staging.tfstate (State Locking)       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Production Architektur

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ PRODUCTION ENVIRONMENT                                                      │
│                                                                             │
│  GitHub Actions (Manual Trigger)                                            │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  gh workflow run "Terraform" -f environment=production -f action=apply│ │
│  │                                                                        │ │
│  │  Security Scan → Init → Validate → Plan → Apply → GitOps Push        │ │
│  │  Auth: OIDC (keine Passwoerter)                                       │ │
│  └──────────────────────────────────┬─────────────────────────────────────┘ │
│                                     │                                       │
│                                     ▼                                       │
│  Azure (northeurope)                                                        │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ Resource Group: rg-mercury-production                                  │ │
│  │                                                                        │ │
│  │  AKS: mercury-production                                               │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │ System Pool: 1x Standard_D2s_v3 (CriticalAddonsOnly)            │  │ │
│  │  │ User Pool:   1x Standard_D2s_v3 (Workloads)                     │  │ │
│  │  │              ↑ Erhoehe auf 2+3 Nodes fuer HA bei Budget          │  │ │
│  │  │                                                                  │  │ │
│  │  │ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────────────┐   │  │ │
│  │  │ │ FluxCD   │ │ Traefik  │ │ Cert-Mgr │ │ CNPG Operator     │   │  │ │
│  │  │ │ (GitOps) │ │ (Ingress)│ │ (TLS)    │ │ (PostgreSQL HA)   │   │  │ │
│  │  │ └──────────┘ └──────────┘ └──────────┘ └───────────────────┘   │  │ │
│  │  │                                                                  │  │ │
│  │  │ Pro Kunde:                                                       │  │ │
│  │  │ ┌────────────────────────────────────────────────────────────┐   │  │ │
│  │  │ │ Namespace: cicero                                          │   │  │ │
│  │  │ │ ├─ n8n Deployment (2+ Replicas, Pod Anti-Affinity)         │   │  │ │
│  │  │ │ ├─ CNPG PostgreSQL (3 Instances, HA)                       │   │  │ │
│  │  │ │ ├─ SecretProviderClass → Key Vault CSI                     │   │  │ │
│  │  │ │ └─ ScheduledBackup (taeglich 03:00 UTC)                    │   │  │ │
│  │  │ └────────────────────────────────────────────────────────────┘   │  │ │
│  │  │                                                                  │  │ │
│  │  │ Monitoring: Prometheus + Grafana (KeyVault Credentials)         │  │ │
│  │  └──────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                        │ │
│  │  Key Vault: kv-merc-production-XXXX (RBAC, Secret Rotation)           │ │
│  │  Storage:   mercurybackupsprod (GRS - geo-redundant!)                 │ │
│  │             ├─ Primary:   North Europe (Dublin)                        │ │
│  │             └─ Secondary: West Europe (Amsterdam, ~800km)              │ │
│  │                                                                        │ │
│  │  Network: Cilium CNI + Network Policies                               │ │
│  │  Auth:    Azure AD RBAC (kubectl via Device Code Flow)                │ │
│  │  Updates: Automatic Patch Upgrades (Sonntag 02:00 UTC)                │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  Remote State: Azure Blob → phase-11/production.tfstate (State Locking)    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Staging vs Production Unterschiede

| | Staging | Production |
|---|---|---|
| Storage Replikation | LRS (lokal) | **GRS (geo-redundant)** |
| DB Instances | 1 | **3 (HA)** |
| n8n Replicas | 1 | **2+ (Anti-Affinity)** |
| Backup Geo-Redundanz | Nein | **Ja (Dublin + Amsterdam)** |

## Customer Onboarding Flow

```
customers.tf                    Terraform Module              GitOps Repo                AKS Cluster
═══════════                     ════════════════              ═══════════                ═══════════

"cicero" ──► module "customers" ──► Generiert 11 YAMLs ──► FluxCD synct ──► Namespace
             │                      ├─ namespace.yaml                       ├─ n8n Pod
             │                      ├─ deployment.yaml                      ├─ PostgreSQL (HA)
             │                      ├─ service.yaml                         ├─ Secrets (Key Vault)
             │                      ├─ database.yaml                        ├─ Backups (Blob)
             │                      ├─ secrets.yaml                         └─ Monitoring
             │                      ├─ configmap.yaml
             │                      ├─ storage.yaml
             │                      ├─ scheduled-backup.yaml
             │                      ├─ ingress.yaml
             │                      ├─ kustomization.yaml
             │                      └─ grafana-secrets.yaml
             │
             ├─ Key Vault Secrets (DB Credentials, SAS Token)
             └─ Blob Container (Backups)
```

## Struktur

```
.
├── .github/workflows/
│   ├── terraform.yml              # Manual Trigger (workflow_dispatch)
│   └── terraform-deploy.yml       # Reusable Workflow (DRY)
├── staging/
│   ├── main.tf                    # AKS, Key Vault, FluxCD
│   ├── customers.tf               # Kundenliste + GitOps Push
│   ├── backups.tf                 # Storage Account (LRS)
│   ├── dns.tf                     # DNS Zone (vorbereitet)
│   └── outputs.tf
├── production/
│   ├── main.tf                    # Identisch, Production Settings
│   ├── customers.tf               # Production Kunden
│   ├── backups.tf                 # Storage Account (GRS!)
│   ├── dns.tf                     # DNS Zone (vorbereitet)
│   └── outputs.tf
└── modules/
    └── customer-n8n/
        ├── variables.tf           # Input mit Validation
        ├── main.tf                # Azure Resources (Blob, SAS)
        ├── secrets.tf             # Key Vault Secrets
        ├── gitops.tf              # Generiert 11 YAML-Dateien
        └── outputs.tf
```
