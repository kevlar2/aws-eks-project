# Infra Deployment Guide

This folder contains Terraform infrastructure code for:
- VPC and networking
- IAM roles and pod identity associations
- EKS cluster, node group, and add-ons

## Folder Layout

- `bootstrap/`: standalone Terraform root to create and harden the S3 backend bucket
- `modules/`: reusable modules (`vpc`, `IAM`, `eks`)
- `main.tf`: root module wiring
- `provider.tf`: provider + remote backend configuration
- `variables.tf`: root input variables
- `outputs.tf`: key operational outputs

## Prerequisites

- Terraform `>= 1.6.5`
- AWS credentials configured in your shell or environment
- AWS CLI installed (optional but recommended for kubeconfig update)

## Important: Deployment Order

This repo uses an S3 backend in `provider.tf`, so bootstrap must run first.

### 1) Create backend bucket (bootstrap root)

```bash
cd infra/bootstrap
terraform init
terraform plan
terraform apply
```

### 2) Deploy main infrastructure (infra root)

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
  - locking: `use_lockfile = true`
- Bootstrap default bucket name must match backend bucket name.

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

## Safety Notes

- Changing `cluster_name` typically forces EKS replacement.
- Node group and add-on changes can trigger rolling replacements.
- Review `terraform plan` carefully before apply.
