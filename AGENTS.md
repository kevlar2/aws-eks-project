# 2048 AWS EKS Project

## Project Overview

Production-grade AWS EKS deployment for a 2048 game application. Covers app containerization with logging, CI/CD pipelines, AWS infrastructure via Terraform (VPC, EKS, IAM), and GitHub OIDC authentication for keyless CI/CD.

## Architecture

- **App**: Vanilla JS (ES5) frontend, custom Python HTTP server, zero npm dependencies — keep it that way
- **Infra**: Terraform with flat structure (`infra/` root module), modules for VPC, EKS, IAM
- **CI/CD**: GitHub Actions — Docker build pipeline + Terraform quality gate pipeline
- **Auth**: GitHub OIDC for keyless AWS authentication in CI
- **Region**: `eu-west-2` (matching `provider.tf`) — NOT `us-east-1`

## Key Conventions

- Image name: `2048-game-app`, image tag uses short SHA (7 chars)
- Port 3000 is already in use on the dev machine — remap with `-p 8081:3000`
- S3 backend uses native S3 locking (`use_lockfile = true`), NOT DynamoDB
- OIDC module is deployed from a separate root (`infra/oidc/`) with its own state file
- The `detect-changes` infra filter intentionally excludes `infra/oidc/**`
- Modules use `locals.tf` pattern with `common_tags` and named resource locals
- ECR exists but push steps in `build-push-image.yaml` remain commented out until K8s/GitOps layer is ready
- Trivy finding IDs in `.trivyignore` use the `AVD-AWS-XXXX` prefix format
- `terraform-tests.yaml` intentionally hardcodes `ENVIRONMENT: dev` — it's a PR quality gate, not a deployment workflow. No need for environment input.
- OIDC role `enable_infra_permissions = true` grants broad `resources = ["*"]` write permissions. Acceptable because: trust policy scoped to this repo + main branch only, single-purpose personal AWS account, resource ARN scoping impractical with dynamic Terraform names.

## Security Notes (Interview Talking Points)

Two architectural patterns in this project are acceptable for a personal/demo project but would need hardening in production:

1. **OIDC role has account-admin-level permissions** (`infra/modules/github-oidc/main.tf`) — The role includes privilege escalation paths (`iam:PassRole`, `iam:UpdateAssumeRolePolicy`, `iam:CreateOpenIDConnectProvider`) with `resources = ["*"]`. In production:
   - Split into separate **plan-only** (read) and **apply** (write) roles
   - Scope `iam:PassRole` to specific role ARNs with `iam:PassedToService` conditions
   - Enforce a permissions boundary on the role
   - Gate the write role behind a protected GitHub environment with required reviewers

2. **PR workflow assumes AWS role on untrusted code** (`terraform-tests.yaml`) — The `pull_request` trigger runs `terraform plan` with real AWS credentials. A malicious PR could execute code during plan (via `external` data sources or custom providers) and exfiltrate temporary credentials. In production:
   - Run only `terraform fmt`/`validate` on PRs (with `terraform init -backend=false`)
   - Or use a **separate read-only AWS role** for PR plans
   - Gate OIDC login to `push` on `main` or a protected environment
   - **Note:** Fork PRs don't get secrets (GitHub restricts this), so external contributors can't exploit this. The risk is only from internal collaborators with write access who could push a malicious branch. For a solo project this is a non-issue.

## Repo Structure

```
.
├── app/                          # 2048 game application + Dockerfile
├── infra/                        # Terraform infrastructure (main root)
│   ├── bootstrap/                # S3 backend bucket (standalone root)
│   ├── oidc/                     # GitHub OIDC provider + IAM role (standalone root)
│   ├── modules/
│   │   ├── vpc/                  # VPC, subnets, NAT gateways, security groups
│   │   ├── IAM/                  # Cluster role, node role, cert-manager, external-dns
│   │   ├── eks/                  # EKS cluster, node group, add-ons
│   │   ├── ecr/                  # ECR repository + lifecycle policy
│   │   ├── pod-identity/         # Generic pod identity associations
│   │   └── github-oidc/          # GitHub OIDC module
│   ├── main.tf                   # Root module wiring
│   ├── provider.tf               # AWS provider + S3 backend
│   └── .tflint.hcl               # TFLint config
├── policies/opa/                 # OPA/Conftest policies (tag enforcement)
├── .github/
│   ├── workflows/
│   │   ├── build-push-image.yaml # Docker CI (build, Trivy, Checkov)
│   │   ├── terraform-tests.yaml  # Terraform quality gate
│   │   ├── terraform-apply.yaml  # Infra deployment (env input, var-file, backend-config)
│   │   └── terraform-destroy.yaml # Infra teardown (env input, destroy confirmation)
│   └── actions/
│       └── aws-oidc-login/       # OIDC composite action
├── .checkov.yml                  # Checkov skip rules
├── .trivyignore                  # Trivy suppressions
└── AGENTS.md                     # This file
```

## Commands

```bash
# Terraform
cd infra && terraform fmt -recursive && terraform validate && terraform plan

# Docker (from app/)
docker build -t 2048-app . && docker run -p 8081:3000 2048-app
```

## Upcoming Work

These are the next tasks to be done, in order:

1. [DONE] **Remove `push` trigger from `terraform-tests.yaml`** — Merged in PR #7; the quality gate now runs on `pull_request` only.
2. **Helmfile bootstrap for ArgoCD** — One-time Helmfile install of ArgoCD into the EKS cluster
3. **ArgoCD app-of-apps** — Root Application CRD that manages all child applications
4. **Observability stack** — `kube-prometheus-stack` (Prometheus + Grafana + Alertmanager) + Loki via ArgoCD
5. **2048 app K8s manifests** — Deployment, Service, Ingress managed by ArgoCD
6. **Uncomment ECR push step + CI image tag update** — Uncomment ECR push in `build-push-image.yaml`, then GitHub Actions commits updated image tag to `k8s/values/game-2048.yaml` after ECR push, ArgoCD syncs
7. **Release documentation** — Add GitHub Release creation to `build-push-image.yaml` so each version bump produces a release with changelog/notes

## Branching Strategy (Recommended)

- Use **one branch per PR-sized change** (avoid a single long-lived branch for all backlog items)
- Keep branch names action-oriented and consistent with existing style
- Merge in this order to reduce risk and conflicts:

1. `fix/terraform-tests-pr-only`
2. `feat/argocd-bootstrap`
3. `feat/gitops-platform-apps`
4. `feat/game-2048-k8s`
5. `feat/ci-ecr-tag-update`
6. `feat/ci-release-automation`

- Rationale:
  - Smaller PRs are easier to review, test, and roll back
  - Infrastructure and platform foundations land before app/workflow changes
  - CI/CD behavior changes are isolated from cluster/application manifest changes

## Execution Checklist (PR-Sized)

- PR 1: Terraform quality gate trigger fix
  - Status: [DONE] Merged in PR #7
  - Update `.github/workflows/terraform-tests.yaml` to remove `push` trigger
  - Keep `pull_request` trigger only
  - Validate workflow syntax and trigger logic
- PR 2: ArgoCD bootstrap foundation
  - Add `k8s/bootstrap/helmfile.yaml` for one-time ArgoCD install
  - Add `k8s/argocd/app-of-apps.yaml` root Application
  - Add `k8s/argocd/values-argocd.yaml` for ArgoCD self-management values
- PR 3: Platform apps via ArgoCD
  - Add `k8s/apps/cert-manager.yaml`, `k8s/apps/external-dns.yaml`, `k8s/apps/kube-prometheus-stack.yaml`, `k8s/apps/loki.yaml`
  - Add corresponding values files under `k8s/values/`
  - Ensure namespaces match infra pod identity expectations (`cert-manager`, `external-dns`, `monitoring`)
- PR 4: 2048 app manifests
  - Add `k8s/apps/game-2048.yaml`
  - Add `k8s/values/game-2048.yaml`
  - Implement Deployment/Service/Ingress for namespace `game-2048`
  - Keep sync policy manual for app rollout control
- PR 5: CI image publish + tag update flow
  - Uncomment/enable ECR push in `.github/workflows/build-push-image.yaml`
  - Add step to update `k8s/values/game-2048.yaml` image tag with short SHA
  - Add commit/push back from workflow (with safe branch/permissions handling)
- PR 6: Release automation
  - Add GitHub Release creation to `.github/workflows/build-push-image.yaml`
  - Generate changelog/notes per release (tag-based or commit-based strategy)

## Order of Operations

- Merge PR 1 first (quick win, removes lock conflict risk)
- Then PR 2 -> PR 3 -> PR 4 (GitOps stack before app rollout)
- Finish with PR 5 and PR 6 (CI/CD publication and release polish)

## Completed Work

### PR #1 (merged) — App + Docker CI
- 2048 app with client-side logging, custom Python HTTP server, Dockerfile
- `build-push-image.yaml` workflow (Docker build, Trivy, Checkov)

### PR #2 (merged) — Terraform infra + quality gate CI
- VPC, EKS, IAM modules, bootstrap S3 backend, OIDC separate root
- `terraform-tests.yaml` workflow (format, validate, TFLint, Trivy, Checkov, Infracost, OPA)

### PR #3 (merged) — `feat/ecr-setup`
- ECR module, pod-identity module, OIDC ECR permissions, semver auto-bump
- `lower()` on all resource names, Dockerfile hardening, launch template drift fix

### PR #4 (merged) — `feat/infra-deploy-workflows`
- `terraform-apply.yaml` and `terraform-destroy.yaml` workflows
- Concurrency groups, `-input=false`, `-lock-timeout=5m`, `confirm_destroy` input

### PR #5 (merged) — `feat/infra-improvements`
- Multi-environment tfvars (dev/prod), separate state keys, EKS access entries
- `enable_infra_permissions` on github-oidc module, environment-suffixed names
- All three workflows updated with environment input, per-env concurrency

### PR #6 (merged) — `fix/oidc-missing-permissions`
- Added `ecr:ListTagsForResource`, `ec2:RunInstances`, `ec2:CreateFleet`, `ec2:CreateLaunchTemplateVersion`, `ec2:DescribeLaunchTemplateVersions`
- Both apply and destroy workflows tested end-to-end and passing

## GitOps Architecture

### Bootstrap flow

```
Terraform (infra/) → EKS cluster + IAM + ECR
  → Helmfile (k8s/bootstrap/) → installs ArgoCD (one-time)
    → ArgoCD → manages everything via app-of-apps:
        ├── ArgoCD itself (self-managed upgrades)
        ├── cert-manager (TLS certificates, Let's Encrypt)
        ├── external-dns (Route53 DNS management)
        ├── kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
        ├── Loki (log aggregation, S3 backend)
        └── 2048-game-app
```

### Repo structure for K8s

```
k8s/
├── bootstrap/
│   └── helmfile.yaml              # Installs ArgoCD only (break-glass tool)
├── argocd/
│   ├── app-of-apps.yaml           # Root Application pointing to apps/
│   └── values-argocd.yaml         # ArgoCD Helm values (self-managed)
├── apps/
│   ├── cert-manager.yaml          # ArgoCD Application CRD
│   ├── external-dns.yaml          # ArgoCD Application CRD
│   ├── kube-prometheus-stack.yaml  # ArgoCD Application CRD
│   ├── loki.yaml                  # ArgoCD Application CRD
│   └── game-2048.yaml             # ArgoCD Application CRD
└── values/
    ├── cert-manager.yaml          # Helm values (ClusterIssuer, DNS solver)
    ├── external-dns.yaml          # Helm values (Route53 zone, domain filter)
    ├── kube-prometheus-stack.yaml  # Helm values for monitoring
    ├── loki.yaml                  # Helm values for Loki
    └── game-2048.yaml             # Helm values for 2048 app
```

### Namespace strategy

- `argocd` — ArgoCD server and components
- `cert-manager` — cert-manager (must match pod identity association in infra/main.tf)
- `external-dns` — external-dns (must match pod identity association in infra/main.tf)
- `monitoring` — kube-prometheus-stack + Loki
- `game-2048` — 2048 application

### Key decisions

- **kube-prometheus-stack** bundles Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics with pre-built dashboards — no need to install separately
- **Loki** stays as a separate chart, added as a Grafana datasource via kube-prometheus-stack values
- **ArgoCD manages itself** after initial Helmfile bootstrap (app-of-apps pattern)
- **Sync policy**: `automated` + `selfHeal: true` for platform apps, manual sync for 2048 app (controlled rollouts)
- **Image tag updates**: GitHub Actions commits updated tag to values file → ArgoCD detects and syncs (simple, auditable)
- **ArgoCD AppProjects**: `platform` (cert-manager, external-dns, monitoring, loki) and `apps` (2048-game) for isolation
