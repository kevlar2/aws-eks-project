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
├── dev.tfvars          # Dev environment variables
├── prod.tfvars         # Prod environment variables
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
Set `enable_infra_permissions = true` to grant full infrastructure deployment permissions (VPC, EKS, IAM, EC2, ECR).

### 3) Deploy main infrastructure (infra root)

First, create a local `infra/terraform.tfvars` (gitignored) with sensitive values:

```hcl
# infra/terraform.tfvars (gitignored, local only)
cluster_admin_arns = ["arn:aws:iam::123456789012:user/your-iam-user"]
route53_zone_id    = "ZXXXXXXXXXXXXXXXXX"
```

Then deploy:

```bash
cd infra
terraform init -backend-config="key=dev/terraform.tfstate"
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

Terraform auto-loads `terraform.tfvars`, so sensitive values from the local file are merged with the environment config from `dev.tfvars`.

## Backend Notes

- Main root backend is configured in `provider.tf`:
  - bucket: `2048-eks-project-dev-ko-tf-state`
  - key: passed at init time via `-backend-config="key=<env>/terraform.tfstate"`
  - region: `eu-west-2`
  - locking: `use_lockfile = true` (native S3 locking, no DynamoDB)
- Each environment (dev, prod) has its own state key (`dev/terraform.tfstate`, `prod/terraform.tfstate`)
- OIDC root has its own state file in the same bucket (different key)
- Bootstrap default bucket name must match backend bucket name.

## Multi-Environment Support

Per-environment `.tfvars` files control environment-specific values. Sensitive values (`cluster_admin_arns`, `route53_zone_id`) are provided separately — via `terraform.tfvars` locally or GitHub secrets in CI.

```bash
# Dev
terraform init -backend-config="key=dev/terraform.tfstate"
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"

# Prod
terraform init -backend-config="key=prod/terraform.tfstate"
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"

# Destroy (any env)
terraform destroy -var-file="dev.tfvars"
```

> **Note:** The above assumes `terraform.tfvars` exists locally with sensitive values (see [Deployment step 3](#3-deploy-main-infrastructure-infra-root)). Alternatively, pass them explicitly:
> ```bash
> terraform plan -var-file="dev.tfvars" \
>   -var='cluster_admin_arns=["arn:aws:iam::123456789012:user/admin"]' \
>   -var='route53_zone_id=ZXXXXXXXXXXXXXXXXX'
> ```

CI workflows accept an `environment` input (default: `dev`) that selects the correct tfvars and state key automatically. Sensitive values are injected via GitHub secrets.

## EKS Cluster Access

The `cluster_admin_arns` variable grants `AmazonEKSClusterAdminPolicy` to specified IAM principals via EKS access entries. This ensures cluster admin access regardless of who creates the cluster (human or CI). Provided via local `terraform.tfvars` or the `CLUSTER_ADMIN_ARNS` GitHub secret in CI.

After apply, connect to the cluster:

```bash
aws eks update-kubeconfig --name <cluster-name> --region eu-west-2
kubectl get nodes
```

### Production considerations

This project uses a single IAM user ARN for cluster admin access, which is appropriate for a demo/personal project. In a production environment with multiple DevOps and SRE engineers, the approach would differ:

**IAM Roles via IAM Identity Center (SSO)**, not individual IAM users. Engineers sign in via an identity provider (Okta, Azure AD, etc.) and assume IAM roles based on their team and permission set:

| Role | EKS Access Policy | Scope |
|------|-------------------|-------|
| `DevOpsAdminRole` | `AmazonEKSClusterAdminPolicy` | Cluster-wide |
| `SRERole` | `AmazonEKSClusterAdminPolicy` | Cluster-wide |
| `DeveloperRole` | `AmazonEKSAdminPolicy` or `AmazonEKSViewPolicy` | Namespace-scoped |

Key differences from the current setup:

- `cluster_admin_arns` would contain **1-2 IAM role ARNs** (not user ARNs), keeping the list small and stable
- Individual engineer onboarding/offboarding happens in IAM Identity Center, not in Terraform
- Namespace-scoped access for developers would use a separate variable (e.g. `cluster_viewer_arns`) with more restrictive EKS access policies
- The `CLUSTER_ADMIN_ARNS` GitHub secret would hold role ARNs like `["arn:aws:iam::123456789012:role/DevOpsAdminRole"]`

This separation means team changes don't require Terraform modifications — only the identity provider configuration changes.

## CI Pipelines

### Terraform Quality Gate (`terraform-tests.yaml`)

Runs on PRs that change `infra/**` files (excluding `infra/oidc/**`).

#### Jobs

1. **detect-changes** — path filtering to only run on infra changes
2. **format-check** — `terraform fmt -check -recursive`
3. **quality-checks** — `terraform init`, `terraform validate`, TFLint, Trivy IaC scan, Checkov scan
4. **infracost** — cost estimation with PR comment
5. **policy-check** — `terraform plan` + OPA/Conftest policy enforcement

### Infra Deployment (`terraform-apply.yaml`)

Triggers on push to main (for `infra/**` changes) or manual `workflow_dispatch` with environment selection.

### Infra Teardown (`terraform-destroy.yaml`)

Manual `workflow_dispatch` only. Requires typing "destroy" to confirm and selecting the target environment.

### Required Secrets

- `AWS_ROLE_ARN` — GitHub OIDC IAM role ARN (from oidc root output)
- `AWS_REGION` — AWS region for deployments
- `CLUSTER_ADMIN_ARNS` — JSON list of IAM ARNs for EKS cluster admin (e.g. `["arn:aws:iam::123456789012:user/admin"]`)
- `ROUTE53_ZONE_ID` — Route53 hosted zone ID for cert-manager DNS validation
- `INFRACOST_API_KEY` — Infracost API key for cost estimation

## Common Commands

From `infra/`:

```bash
terraform fmt -recursive
terraform validate
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
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
