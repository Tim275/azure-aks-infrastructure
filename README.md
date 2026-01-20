# Phase 11 Enterprise

Multi-Tenant AKS Platform with GitOps.

## Structure

```
.
├── .github/workflows/
│   ├── terraform.yml
│   └── terraform-deploy.yml
├── staging/
│   ├── main.tf
│   ├── customers.tf
│   └── backups.tf
├── production/
│   ├── main.tf
│   ├── customers.tf
│   └── backups.tf
└── modules/
    └── customer-n8n/
        ├── variables.tf
        ├── secrets.tf
        └── gitops.tf
```
