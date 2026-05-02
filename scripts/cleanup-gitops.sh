#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_OF_APPS_PATH="$ROOT_DIR/k8s/argocd/app-of-apps.yaml"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf "Missing required command: %s\n" "$1" >&2
    exit 1
  fi
}

disable_autosync() {
  local app="$1"
  kubectl patch application "$app" -n argocd --type merge \
    -p '{"spec":{"syncPolicy":{"automated":null}}}' >/dev/null 2>&1 || true
}

strip_finalizer() {
  local app="$1"
  kubectl patch application "$app" -n argocd --type json \
    -p '[{"op":"remove","path":"/metadata/finalizers"}]' >/dev/null 2>&1 || true
}

delete_if_exists() {
  kubectl delete "$@" --ignore-not-found >/dev/null 2>&1 || true
}

require_cmd kubectl

printf "[1/7] Disabling ArgoCD auto-sync on managed applications...\n"
for app in cert-manager external-dns kube-prometheus-stack loki promtail game-2048; do
  disable_autosync "$app"
done

printf "[2/7] Deleting ingress DNS sources...\n"
delete_if_exists ingress argocd-server -n argocd
delete_if_exists ingress kube-prometheus-stack-grafana -n monitoring
delete_if_exists ingress game-2048 -n game-2048
kubectl annotate svc -n ingress-nginx ingress-nginx-controller \
  external-dns.alpha.kubernetes.io/hostname- --overwrite >/dev/null 2>&1 || true

printf "[3/7] Stripping ArgoCD finalizers to prevent deletion deadlock...\n"
# ArgoCD finalizers cause cascade deletion of managed resources, but if any child
# resource is stuck (e.g. cert-manager webhook, CRD with finalizer), the Application
# deletion hangs indefinitely. Stripping finalizers first lets Kubernetes complete
# the deletion immediately. Resources in each namespace will be cleaned up in step 4.
for app in game-2048 cert-manager external-dns kube-prometheus-stack loki promtail argocd-app-of-apps; do
  strip_finalizer "$app"
done

printf "[4/7] Deleting app-of-apps root application...\n"
delete_if_exists -f "$APP_OF_APPS_PATH"

printf "[5/7] Deleting ArgoCD applications...\n"
for app in game-2048 cert-manager external-dns kube-prometheus-stack loki promtail; do
  delete_if_exists application "$app" -n argocd
done

printf "[6/7] Deleting ArgoCD AppProjects...\n"
for project in apps platform; do
  delete_if_exists appproject "$project" -n argocd
done

printf "[7/7] Current ArgoCD applications (if any):\n"
kubectl get applications -n argocd 2>/dev/null || true

cat <<'EOF'

Cleanup complete.

Important:
- This repo uses external-dns policy `upsert-only`, so Route53 records are NOT auto-deleted.
- Manually delete DNS records for:
  - argocd.kubevpro.bluebird-investments.co.uk
  - grafana.monitoring.kubevpro.bluebird-investments.co.uk
  - app.kubevpro.bluebird-investments.co.uk
- Then run infra destroy workflows/terraform if you are tearing down EKS.
EOF
