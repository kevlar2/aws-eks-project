# Infra Deployment Guide

This folder contains Terraform infrastructure code for:
- VPC and networking
- IAM roles and pod identity associations
- EKS cluster, node group, and add-ons
- ECR container image repository
- GitHub OIDC authentication for CI/CD

## Folder Layout

```
infra/
├── bootstrap/          # Standalone root: S3 backend bucket
├── oidc/               # Standalone root: GitHub OIDC provider + IAM role (separate state)
├── modules/
│   ├── vpc/            # VPC, subnets, NAT gateways, security groups
│   ├── IAM/            # Cluster role, node role, cert-manager, external-dns pod identity
│   ├── eks/            # EKS cluster, node group, launch template, add-ons, OIDC provider
│   ├── ecr/            # ECR repository with lifecycle policy and scan-on-push
│   ├── pod-identity/   # Pod identity associations (breaks IAM/EKS circular dependency)
│   └── github-oidc/    # GitHub OIDC provider + CI IAM role module
├── main.tf             # Root module wiring
├── provider.tf         # AWS provider + S3 backend (eu-west-2)
├── variables.tf        # Root input variables
├── outputs.tf          # Key operational outputs
└── .tflint.hcl         # TFLint configuration (AWS plugin v0.47.0)
```

**Related files at repo root:**
- `.checkov.yml` — Checkov skip rules for dev environment
- `.trivyignore` — Trivy finding suppressions (AVD-AWS-* format)
- `policies/opa/terraform.rego` — OPA tag enforcement and security policies
- `.github/workflows/terraform-tests.yaml` — Terraform quality gate CI pipeline
- `.github/actions/aws-oidc-login/action.yml` — OIDC composite action for CI

## Prerequisites

- Terraform `>= 1.6.5`
- AWS credentials configured in your shell or environment
- AWS CLI installed (optional but recommended for kubeconfig update)

## Important: Deployment Order

This repo uses an S3 backend in `provider.tf`, so bootstrap must run first.
The OIDC root is deployed separately to avoid chicken-and-egg problems with the main infra.

### 1) Create backend bucket (bootstrap root)

```bash
cd infra/bootstrap
terraform init
terraform plan
terraform apply
```

### 2) Deploy OIDC provider (oidc root)

```bash
cd infra/oidc
terraform init
terraform plan
terraform apply
```

This creates the GitHub OIDC provider and IAM role that the CI pipeline uses.
The OIDC role has read-only permissions + S3 state access + ECR push access.

### 3) Deploy main infrastructure (infra root)

```bash
cd infra
terraform init
terraform plan
terraform apply
```

## Backend Notes

- Main root backend is configured in `provider.tf`:
  - bucket: `2048-eks-project-dev-ko-tf-state`
  - key: `2048/terraform.tfstate`
  - region: `eu-west-2`
  - locking: `use_lockfile = true` (native S3 locking, no DynamoDB)
- OIDC root has its own state file in the same bucket (different key)
- Bootstrap default bucket name must match backend bucket name.

## CI Pipeline (Terraform Quality Gate)

The `.github/workflows/terraform-tests.yaml` workflow runs on PRs that change `infra/**` files (excluding `infra/oidc/**`).

### Jobs

1. **detect-changes** — path filtering to only run on infra changes
2. **format-check** — `terraform fmt -check -recursive`
3. **quality-checks** — `terraform init`, `terraform validate`, TFLint, Trivy IaC scan, Checkov scan
4. **infracost** — cost estimation with PR comment
5. **policy-check** — `terraform plan` + OPA/Conftest policy enforcement

### Required Secrets

- `AWS_ROLE_ARN` — GitHub OIDC IAM role ARN (from oidc root output)
- `AWS_REGION` — AWS region for ECR and other services
- `INFRACOST_API_KEY` — Infracost API key for cost estimation

## Common Commands

From `infra/`:

```bash
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform output
```

Get kubeconfig command from output:

```bash
terraform output kubeconfig_update_command
```

Then run the printed command to connect `kubectl` to the cluster.

## Current Output Contract

Root outputs are intentionally minimal and operator-focused:
- `vpc_id`
- `public_subnet_id`
- `private_subnet_id`
- `security_group_id`
- `eks-role-arn`
- `eks-node-arn`
- `cert-manager-role-arn`
- `external-dns-role-arn`
- `eks-cluster-name`
- `kubeconfig_update_command`
- `ecr_repository_url`
- `ecr_repository_arn`

## Safety Notes

- Changing `cluster_name` typically forces EKS replacement.
- Node group and add-on changes can trigger rolling replacements.
- Review `terraform plan` carefully before apply.
- The OIDC root is intentionally separate — do not move it into the main infra root.
