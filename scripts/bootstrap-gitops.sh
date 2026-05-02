#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELMFILE_PATH="$ROOT_DIR/k8s/bootstrap/helmfile.yaml"
APPS_PATH="$ROOT_DIR/k8s/argocd/app-of-apps.yaml"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf "Missing required command: %s\n" "$1" >&2
    exit 1
  fi
}

require_cmd helmfile
require_cmd kubectl
require_cmd openssl

printf "[1/5] Bootstrapping ArgoCD + ingress-nginx with Helmfile...\n"
helmfile -f "$HELMFILE_PATH" sync

printf "[2/5] Waiting for ArgoCD deployments...\n"
kubectl -n argocd rollout status deploy/argocd-server --timeout=5m
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=5m

printf "[3/5] Waiting for ingress-nginx controller...\n"
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=10m

printf "[4/5] Creating out-of-band secrets (not stored in Git)...\n"

# Grafana admin credentials
# kube-prometheus-stack references this secret via grafana.admin.existingSecret.
# It must exist in the monitoring namespace before the Grafana pod starts.
# Without it, all three Grafana sidecar containers fail with "secret not found".
# The monitoring namespace is created here explicitly because ArgoCD creates it
# only after app-of-apps is applied in the next step.
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - >/dev/null
if kubectl -n monitoring get secret kube-prometheus-stack-grafana >/dev/null 2>&1; then
  printf "  grafana admin secret already exists, skipping.\n"
else
  GRAFANA_PASSWORD=$(openssl rand -base64 16)
  kubectl -n monitoring create secret generic kube-prometheus-stack-grafana \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$GRAFANA_PASSWORD"
  printf "  grafana admin secret created.\n"
  printf "  Grafana password (save this now): %s\n" "$GRAFANA_PASSWORD"
fi

printf "[5/5] Applying app-of-apps root Application...\n"
kubectl apply -f "$APPS_PATH"

printf "\nBootstrap complete. Current ArgoCD applications:\n"
kubectl -n argocd get applications
