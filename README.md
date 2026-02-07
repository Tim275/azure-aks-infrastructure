# Enterprise Multi-Tenant AKS Platform

Infrastructure-as-Code Plattform fuer Multi-Tenant Kubernetes auf Azure.
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
│  │  Auth: OIDC (keine Passwoerter, nur Tokens)                    │         │    │
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
