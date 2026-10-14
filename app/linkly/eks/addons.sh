#!/usr/bin/env bash
# Installs the cluster add-ons Linkly needs in production (module 8), pinned, into the current
# kubectl context: Envoy Gateway (Gateway API), cert-manager (certificates), External Secrets
# (AWS secrets → Kubernetes Secrets), Reloader (restart on rotation), metrics-server (autoscaling).
# The kind rehearsal uses the same script, so what you rehearse is what you run.
set -euo pipefail
ENVOY_GATEWAY=v1.9.2 CERT_MANAGER=v1.21.2 EXTERNAL_SECRETS=2.12.0 RELOADER=2.2.18 METRICS_SERVER=3.14.0
metrics_args=()
[ "${KIND:-0}" = 1 ] && metrics_args=(--set 'args={--kubelet-insecure-tls}')   # kind's kubelets have self-signed certs

helm repo add jetstack https://charts.jetstack.io --force-update >/dev/null
helm repo add external-secrets https://charts.external-secrets.io --force-update >/dev/null
helm repo add stakater https://stakater.github.io/stakater-charts --force-update >/dev/null
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update >/dev/null

echo "== Envoy Gateway $ENVOY_GATEWAY"
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm --version "$ENVOY_GATEWAY" \
  -n envoy-gateway-system --create-namespace --wait
kubectl apply -f - <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
YAML
echo "== cert-manager $CERT_MANAGER"
helm upgrade --install cert-manager jetstack/cert-manager --version "$CERT_MANAGER" \
  -n cert-manager --create-namespace --set crds.enabled=true --set config.enableGatewayAPI=true --wait
echo "== External Secrets $EXTERNAL_SECRETS"
helm upgrade --install external-secrets external-secrets/external-secrets --version "$EXTERNAL_SECRETS" \
  -n external-secrets --create-namespace --wait
echo "== Reloader $RELOADER"
helm upgrade --install reloader stakater/reloader --version "$RELOADER" -n reloader --create-namespace --wait
echo "== metrics-server $METRICS_SERVER"
helm upgrade --install metrics-server metrics-server/metrics-server --version "$METRICS_SERVER" \
  -n kube-system "${metrics_args[@]}" --wait
echo "add-ons installed"
