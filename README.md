# Enterprise Multi-Tenant AKS Platform

Infrastructure-as-Code Plattform für Multi-Tenant Kubernetes auf Azure.
Neuer Kunde = eine Zeile in `customers.tf` - der Rest passiert automatisch.

## Architektur

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                                                                                  │
│  DEVELOPER                                                                       │
│  ════════                                                                        │
│  git push (staging branch)           git push (main branch)                      │
│       │                                    │                                     │
│       ▼                                    ▼                                     │
│  ┌──────────────────────────────────────────────────────────────────────────┐    │
│  │                        GITHUB ACTIONS (CI/CD)                            │    │
│  │                                                                          │    │
│  │  ┌────────────┐  ┌─────────┐  ┌──────────┐  ┌───────┐  ┌─────────────┐  │    │
│  │  │  Security   │  │  Init   │  │ Validate │  │ Plan  │  │   Apply /   │  │    │
│  │  │  TFSec +    │→ │         │→ │  + Fmt   │→ │       │→ │   Destroy   │  │    │
│  │  │  Checkov    │  │         │  │          │  │       │  │             │  │    │
│  │  └────────────┘  └─────────┘  └──────────┘  └───────┘  └──────┬──────┘  │    │
│  │                                                                │         │    │
│  │  Auth: OIDC (keine Passwörter, nur Tokens)                     │         │    │
│  └────────────────────────────────────────────────────────────────┼─────────┘    │
│                                                                   │              │
│       ┌───────────────────────────────────────────────────────────┘              │
│       │                                                                          │
│       ▼                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────┐    │
│  │                              AZURE                                       │    │
│  │                                                                          │    │
│  │   STAGING                                  PRODUCTION                    │    │
│  │   ┌────────────────────────────┐           ┌────────────────────────┐    │    │
│  │   │ AKS Cluster                │           │ AKS Cluster            │    │    │
│  │   │ ├─ FluxCD (GitOps)         │           │ ├─ FluxCD (GitOps)     │    │    │
│  │   │ ├─ CNPG PostgreSQL (HA)    │           │ ├─ CNPG PostgreSQL     │    │    │
│  │   │ ├─ Traefik Ingress         │           │ ├─ Traefik Ingress     │    │    │
│  │   │ ├─ Cert-Manager            │           │ ├─ Cert-Manager        │    │    │
│  │   │ └─ Prometheus + Grafana    │           │ └─ Prometheus + Grafana│    │    │
│  │   │                            │           │                        │    │    │
│  │   │ Key Vault (Secrets)        │           │ Key Vault (Secrets)    │    │    │
│  │   │ Storage: LRS (lokal)       │           │ Storage: GRS (geo)     │    │    │
│  │   └────────────────────────────┘           └────────────────────────┘    │    │
│  │                                                                          │    │
│  │   Shared                                                                 │    │
│  │   ┌─────────────────────────────────────────────────────────────────┐    │    │
│  │   │ Remote State: Azure Blob Storage (State Locking)                │    │    │
│  │   │ ├─ phase-11/staging.tfstate                                     │    │    │
│  │   │ └─ phase-11/production.tfstate                                  │    │    │
│  │   └─────────────────────────────────────────────────────────────────┘    │    │
│  └──────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│       ┌──────────────────────────────────────────────────────┐                   │
│       │                  GITOPS REPO                          │                   │
│       │          (mercury-gitops-v2)                          │                   │
│       │                                                      │                   │
│       │  Terraform generiert YAML ──► Git Push               │                   │
│       │                                   │                  │                   │
│       │                          FluxCD synct (60s)          │                   │
│       │                                   │                  │                   │
│       │                          Cluster konfiguriert sich   │                   │
│       └──────────────────────────────────────────────────────┘                   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

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

Neuer Kunde = eine Zeile hinzufuegen, `git push`, fertig.

## Struktur

```
.
├── .github/workflows/
│   ├── terraform.yml              # Branch-Routing (staging/main)
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

## Staging vs Production

| Aspekt | Staging | Production |
|--------|---------|------------|
| Branch | `staging` | `main` |
| Backup Storage | LRS (lokal redundant) | GRS (geo-redundant) |
| DB Replicas | 2 (1 Primary + 1 Replica) | 3+ (HA) |
| n8n Replicas | 1 | 2+ |
| Zweck | Testen, Validieren | Kundenbetrieb |

## CI/CD Pipeline

```
Push to Branch
     │
     ├─ staging branch ──► Deploy Staging
     │
     ├─ main branch ──► Deploy Production
     │
     └─ PR main ──► Plan Only (Review)

Pipeline Steps:
  Security Scan (TFSec + Checkov)
  → Init → Format Check → Validate
  → Plan → Apply/Destroy
  → GitOps Push → FluxCD Sync
```

**Auth:** OIDC (OpenID Connect) - keine Passwörter in GitHub, nur kurzlebige Tokens.

**Concurrency:** Nur ein Deploy pro Environment gleichzeitig.

## Technologien

| Kategorie | Tool | Zweck |
|-----------|------|-------|
| IaC | Terraform | Infrastruktur provisionieren |
| Cluster | Azure AKS | Managed Kubernetes |
| GitOps | FluxCD | Git → Cluster Sync |
| Database | CloudNative-PG | PostgreSQL HA im Cluster |
| Secrets | Azure Key Vault + CSI Driver | Sichere Secret-Verwaltung |
| Ingress | Traefik | Load Balancer + Routing |
| TLS | Cert-Manager + Let's Encrypt | Automatische Zertifikate |
| Monitoring | Prometheus + Grafana | Metriken + Dashboards |
| Backups | Barman Cloud | CNPG → Azure Blob (PITR) |
| Security | TFSec + Checkov | IaC Security Scanning |
| Auth | Azure AD RBAC | kubectl Zugriffskontrolle |

## Befehle

```bash
# Manueller Deploy/Destroy
gh workflow run "Terraform" -f environment=staging -f action=apply
gh workflow run "Terraform" -f environment=staging -f action=destroy
gh workflow run "Terraform" -f environment=production -f action=apply
gh workflow run "Terraform" -f environment=production -f action=destroy

# Status
gh run list --workflow="Terraform" --limit=5
gh run watch

# kubectl (erfordert Azure AD Login)
az aks get-credentials --resource-group rg-mercury-staging --name mercury-staging
kubectl get pods -A
```

## Was ich gelernt habe

**Terraform & IaC**
- Remote State mit Azure Blob Storage und State Locking fuer Team-Arbeit
- Wiederverwendbare Module mit `for_each` fuer Multi-Tenant Skalierung
- Variable Validation fuer Enterprise-Standard Input-Pruefung
- `local_file` Resource um aus Terraform heraus GitOps-Manifeste zu generieren

**Kubernetes & AKS**
- Azure Managed Kubernetes mit Azure AD RBAC Integration
- Namespace-Isolation fuer Multi-Tenancy (1 Cluster, viele Kunden)
- CloudNative-PG fuer PostgreSQL High Availability direkt im Cluster
- CSI Secret Store Driver fuer sichere Key Vault Integration

**GitOps & FluxCD**
- Git als Single Source of Truth fuer die gesamte Cluster-Konfiguration
- Kustomize Base/Overlay Pattern fuer Environment-spezifische Patches
- Race Condition Fix mit `time_sleep` nach Git Push (FluxCD Sync Timing)
- Automatische Reconciliation alle 60 Sekunden

**CI/CD & Security**
- GitHub Actions mit OIDC Authentication (keine langlebigen Credentials)
- Reusable Workflows (DRY - ein Workflow fuer beide Environments)
- Security Scanning mit TFSec und Checkov in der Pipeline
- Branch-basierte Deployment-Strategie (staging Branch → Staging, main → Production)

**Backup & Disaster Recovery**
- CNPG Barman Cloud Plugin fuer automatische Backups zu Azure Blob
- WAL Archiving fuer Point-in-Time Recovery (PITR) auf jede Sekunde
- LRS vs GRS Storage: geo-redundante Backups fuer Production
- Scheduled Backups mit CronJob (taeglich 03:00 UTC)

**Problemloesung**
- Terraform State Lock Recovery bei abgebrochenen Workflows
- vCPU Quota Management (Azure Free Tier Limits)
- Azure Subscription Lifecycle (Free Trial → Pay-As-You-Go)
