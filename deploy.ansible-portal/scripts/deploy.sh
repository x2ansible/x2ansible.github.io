#!/usr/bin/env bash
# Deploy X2A on the Automation Portal operator (Path 1).
#
# Prerequisites:
#   * `oc` logged in as cluster-admin.
#   * A GitHub OAuth App created (see README Step 2); its Client ID/Secret filled into
#     manifests/05-secrets.yaml (copied from the .example).
#   * Entitled registry.redhat.io pull credentials in a docker-config-json file, exported as
#     REG_AUTH_FILE (defaults to the cluster's global pull-secret, extracted automatically).
set -euo pipefail

NS="${NS:-automation-portal}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFESTS="$HERE/manifests"
SECRET="$MANIFESTS/05-secrets.yaml"

echo "==> Target namespace: $NS"

# Manifests ship with the sample namespace `automation-portal`. Retarget to $NS on the fly.
apply() { sed "s/automation-portal/${NS}/g" "$1" | oc apply -f -; }

if [[ ! -f "$SECRET" ]]; then
  echo "ERROR: $SECRET not found."
  echo "       cp $MANIFESTS/05-secrets.yaml.example $SECRET  and fill in the GitHub OAuth App values."
  exit 1
fi

# 1) Operators (namespace, RHDH sub, Portal OperatorGroup + sub)
echo "==> Installing operators (RHDH + Automation Portal)"
apply "$MANIFESTS/00-operators.yaml"

echo "==> Waiting for both operator CSVs to reach Succeeded..."
for csv_ns in "openshift-operators:rhdh" "$NS:automation-portal-operator"; do
  ns="${csv_ns%%:*}"; want="${csv_ns##*:}"
  for i in $(seq 1 60); do
    if oc get csv -n "$ns" 2>/dev/null | grep -E "$want" | grep -q Succeeded; then
      echo "    $want CSV Succeeded in $ns"; break
    fi
    sleep 10
    [[ "$i" == 60 ]] && { echo "ERROR: $want CSV not Succeeded in $ns"; exit 1; }
  done
done

# 2) CA-bundle secret — trust the in-cluster API server CA so X2A's kube connection test passes.
#    Built from the per-namespace kube-root-ca.crt ConfigMap. Wired via spec.backstage.caCertificates.
echo "==> Building x2a-ca-bundle secret from kube-root-ca.crt"
CA_TMP="$(mktemp)"
oc get configmap kube-root-ca.crt -n "$NS" -o jsonpath='{.data.ca\.crt}' > "$CA_TMP"
oc create secret generic x2a-ca-bundle -n "$NS" \
  --from-file=ca-bundle.crt="$CA_TMP" \
  --dry-run=client -o yaml | oc apply -f -
rm -f "$CA_TMP"

# 3) Registry-auth secret — the operator's install-dynamic-plugins init container uses skopeo,
#    which searches for a file named `auth.json` (NOT .dockerconfigjson). Build an Opaque secret
#    carrying key `auth.json` from your entitled registry.redhat.io credentials.
echo "==> Building portal-registry-auth secret (key: auth.json)"
REG_TMP=""
if [[ -z "${REG_AUTH_FILE:-}" ]]; then
  REG_TMP="$(mktemp)"; REG_AUTH_FILE="$REG_TMP"
  oc get secret pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > "$REG_AUTH_FILE"
  echo "    (using the cluster global pull-secret; override with REG_AUTH_FILE=<path>)"
fi
oc create secret generic portal-registry-auth -n "$NS" \
  --from-file=auth.json="$REG_AUTH_FILE" \
  --from-file=.dockerconfigjson="$REG_AUTH_FILE" \
  --dry-run=client -o yaml | oc apply -f -
[[ -n "$REG_TMP" ]] && rm -f "$REG_TMP"

# 4) App secrets (GitHub OAuth + placeholder AAP)
echo "==> Applying app secrets (GitHub OAuth + placeholder AAP)"
apply "$SECRET"

# 5) X2A overlay ConfigMaps + RBAC
echo "==> Applying X2A overlay (dynamic-plugins, app-config, RBAC)"
apply "$MANIFESTS/02-x2a-dynamic-plugins.configmap.yaml"
apply "$MANIFESTS/03-app-config-x2a.configmap.yaml"
apply "$MANIFESTS/04-namespace-rbac.yaml"

# 6) The AutomationPortal CR
echo "==> Applying the AutomationPortal CR"
apply "$MANIFESTS/01-automationportal.yaml"

echo "==> Waiting for the AutomationPortal to reconcile to Ready (first boot pulls all plugins)..."
if ! oc wait --for=condition=Ready automationportal/portal -n "$NS" --timeout=900s; then
  echo "ERROR: AutomationPortal not Ready within 900s."
  echo "NOTE: First boot is slow (large plugin set + lightspeed RAG sidecar) and may restart once"
  echo "      or twice against the startup probe. Wait for the pod to reach 2/2 Running, then"
  echo "      re-run: NS=$NS scripts/verify.sh"
  exit 1
fi

HOST="$(oc get route backstage-portal-backstage -n "$NS" -o jsonpath='{.spec.host}' 2>/dev/null || true)"
echo
echo "======================================================================"
echo "Route:    https://${HOST:-<pending>}"
echo
echo "GitHub OAuth App Authorization callback URL must be:"
echo "  https://${HOST:-backstage-portal-backstage-${NS}.apps.<cluster-domain>}/api/auth/github/handler/frame"
echo
echo "Then run: NS=$NS scripts/verify.sh"
echo "======================================================================"
