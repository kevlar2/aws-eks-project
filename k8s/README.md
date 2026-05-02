# k8s

Kubernetes GitOps configuration for the 2048 game platform on EKS.

ArgoCD manages all workloads via the app-of-apps pattern. The only manual step is the initial bootstrap — after that ArgoCD owns the cluster state.

---

## Directory Structure

```
k8s/
├── bootstrap/          # One-time Helmfile install (ArgoCD + ingress-nginx)
├── argocd/             # ArgoCD root Application and self-managed Helm values
├── apps/               # ArgoCD Application and AppProject manifests
├── charts/             # Local Helm charts
│   └── game-2048/      # Helm chart for the 2048 app
└── values/             # Helm values files (referenced by ArgoCD Applications)
```

---

## Bootstrap

The cluster is bootstrapped in two phases. A convenience script wraps both:

```bash
./scripts/bootstrap-gitops.sh
```

### What it does

| Step | Action |
|------|--------|
| 1 | Helmfile installs ArgoCD and ingress-nginx into the cluster |
| 2 | Waits for ArgoCD server and repo-server rollouts |
| 3 | Waits for ingress-nginx controller rollout |
| 4 | Creates the `kube-prometheus-stack-grafana` admin secret in `monitoring` (out-of-band — not stored in Git) |
| 5 | Applies `k8s/argocd/app-of-apps.yaml` — ArgoCD takes over from here |

After step 5, ArgoCD syncs all platform apps and the 2048 app automatically.

> **Note:** The Grafana admin password is printed once at bootstrap time. Save it — it cannot be recovered without recreating the secret.

### Manual bootstrap (step by step)

```bash
# Phase 1: install ArgoCD + ingress-nginx
helmfile -f k8s/bootstrap/helmfile.yaml sync

# Phase 2: create out-of-band secrets
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl -n monitoring create secret generic kube-prometheus-stack-grafana \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=<your-password>

# Phase 3: apply app-of-apps
kubectl apply -f k8s/argocd/app-of-apps.yaml
```

---

## Teardown

```bash
./scripts/cleanup-gitops.sh
```

### What it does

| Step | Action |
|------|--------|
| 1 | Disables ArgoCD auto-sync on all apps (prevents fight-back during deletion) |
| 2 | Deletes Ingress resources so `external-dns` can remove Route53 records before it shuts down |
| 3 | Strips ArgoCD finalizers to prevent deletion deadlock |
| 4 | Deletes the app-of-apps root Application |
| 5 | Deletes all ArgoCD Applications |
| 6 | Deletes all ArgoCD AppProjects |
| 7 | Prints remaining applications and Route53 cleanup reminder |

> **Important:** `external-dns` uses `policy: upsert-only` — it never auto-deletes Route53 records. After running the script, manually verify and delete DNS records for:
> - `argocd.kubevpro.bluebird-investments.co.uk`
> - `app.kubevpro.bluebird-investments.co.uk`
> - `grafana.monitoring.kubevpro.bluebird-investments.co.uk`

---

## ArgoCD App-of-Apps

`k8s/argocd/app-of-apps.yaml` is the root ArgoCD Application. It watches `k8s/apps/` on the `main` branch and creates all child Applications from the manifests found there.

```
argocd-app-of-apps  (root, watches k8s/apps/)
├── platform-project    (AppProject — platform namespace guardrails)
├── apps-project        (AppProject — game-2048 namespace guardrails)
├── cert-manager        (project: platform)
├── external-dns        (project: platform)
├── kube-prometheus-stack (project: platform)
├── loki                (project: platform)
├── promtail            (project: platform)
└── game-2048           (project: apps)
```

---

## AppProjects

AppProjects are ArgoCD security boundaries. They control which repos, namespaces, and cluster-scoped resource types an Application is allowed to use.

| Project | File | Allowed namespaces | Cluster resources |
|---------|------|--------------------|-------------------|
| `platform` | `apps/platform-project.yaml` | `cert-manager`, `external-dns`, `monitoring` | `Namespace` |
| `apps` | `apps/apps-project.yaml` | `game-2048` | `Namespace` |

The `Namespace` entry in `clusterResourceWhitelist` is required for `CreateNamespace=true` to work. Without it ArgoCD blocks namespace creation with `resource :Namespace is not permitted in project`.

---

## Applications

| Application | File | Chart | Sync | Namespace |
|-------------|------|-------|------|-----------|
| `cert-manager` | `apps/cert-manager.yaml` | `jetstack/cert-manager` | Automated | `cert-manager` |
| `external-dns` | `apps/external-dns.yaml` | `bitnami/external-dns` | Automated | `external-dns` |
| `kube-prometheus-stack` | `apps/kube-prometheus-stack.yaml` | `prometheus-community/kube-prometheus-stack` | Automated | `monitoring` |
| `loki` | `apps/loki.yaml` | `grafana/loki` | Automated | `monitoring` |
| `promtail` | `apps/promtail.yaml` | `grafana/promtail` | Automated | `monitoring` |
| `game-2048` | `apps/game-2048.yaml` | `k8s/charts/game-2048` (local) | **Manual** | `game-2048` |

Platform apps use automated sync with `selfHeal: true`. The 2048 app uses **manual sync** for controlled rollouts — it will not deploy automatically on Git push.

### Syncing game-2048 manually

```bash
# via ArgoCD CLI
argocd app sync game-2048

# via kubectl
kubectl patch application game-2048 -n argocd --type merge \
  -p '{"operation":{"sync":{"prune":true,"syncOptions":["CreateNamespace=true"]}}}'
```

---

## Helm Chart: game-2048

Located at `k8s/charts/game-2048/`. A minimal chart that renders a Deployment, Service, and Ingress.

The chart ships with safe defaults — `ingress.enabled: false` and an empty `image.repository` — so it cannot accidentally deploy without explicit values.

Production values are in `k8s/values/game-2048.yaml` and referenced by the ArgoCD Application via the multi-source `$values` pattern.

### Key values (`k8s/values/game-2048.yaml`)

| Key | Value |
|-----|-------|
| `image.repository` | `948700347171.dkr.ecr.eu-west-2.amazonaws.com/2048-game-app` |
| `image.tag` | `latest` (updated by CI in PR #5) |
| `containerPort` | `3000` (custom Python HTTP server) |
| `ingress.host` | `app.kubevpro.bluebird-investments.co.uk` |
| `ingress.annotations` | cert-manager TLS + external-dns hostname |

---

## Ingress and DNS

All traffic enters through a single AWS NLB created by the `ingress-nginx` controller. Routing is hostname-based.

| Hostname | Backend |
|----------|---------|
| `argocd.kubevpro.bluebird-investments.co.uk` | `argocd/argocd-server` |
| `app.kubevpro.bluebird-investments.co.uk` | `game-2048/game-2048` |
| `grafana.monitoring.kubevpro.bluebird-investments.co.uk` | `monitoring/kube-prometheus-stack-grafana` |

`external-dns` watches Ingress resources and manages Route53 records automatically. TLS certificates are issued by `cert-manager` via Let's Encrypt DNS01 challenge against Route53.

---

## Namespace Strategy

| Namespace | Workloads |
|-----------|-----------|
| `argocd` | ArgoCD server, repo-server, application-controller, dex |
| `ingress-nginx` | ingress-nginx controller |
| `cert-manager` | cert-manager, cainjector, webhook |
| `external-dns` | external-dns |
| `monitoring` | Prometheus, Grafana, Alertmanager, Loki, Promtail |
| `game-2048` | 2048 app |

---

## Follow-Up Work

- **ESO + AWS Secrets Manager** — replace out-of-band Grafana secret with an `ExternalSecret` managed by External Secrets Operator
- **Prometheus PVC** — add persistent storage to avoid ephemeral metrics on pod restart
- **ECR image tag** — PR #5 will wire CI to commit the short-SHA tag to `k8s/values/game-2048.yaml` after each ECR push
