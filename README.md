# Enterprise Multi-Tenant AKS Platform

Infrastructure-as-Code Plattform fuer Multi-Tenant Kubernetes auf Azure.
Neuer Kunde = eine Zeile in `customers.tf` - der Rest passiert automatisch.

## Architecture

<p align="center">
  <a href="docs/architecture.svg">
    <img src="docs/architecture.svg" alt="Architecture" width="100%">
  </a>
</p>

### Staging vs Production

| | Staging | Production |
|---|---|---|
| Storage Replication | LRS (local) | **GRS (geo-redundant)** |
| DB Instances | 1 | **3 (HA)** |
| n8n Replicas | 1 | **2+ (Anti-Affinity)** |
| Backup Geo-Redundancy | No | **Yes (Dublin + Amsterdam)** |

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
