# Enterprise Multi-Tenant AKS Platform

Infrastructure-as-Code Plattform fuer Multi-Tenant Kubernetes auf Azure.





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

