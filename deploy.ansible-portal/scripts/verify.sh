#!/usr/bin/env bash
# Verify the Path-1 X2A deployment (Automation Portal operator). Safe to run repeatedly.
set -uo pipefail

NS="${NS:-automation-portal}"
pass=0; fail=0
ok()  { echo "PASS: $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1"; fail=$((fail+1)); }

echo "==> Namespace: $NS"

# 1) AutomationPortal CR reconciled (Ready + BackstageReady)
for cond in Ready BackstageReady; do
  if oc get automationportal portal -n "$NS" \
       -o jsonpath="{range .status.conditions[?(@.type==\"$cond\")]}{.status}{end}" 2>/dev/null | grep -q True; then
    ok "AutomationPortal condition $cond=True"
  else
    bad "AutomationPortal condition $cond is not True yet"
  fi
done

# 2) Backstage pod 2/2 Running
POD="$(oc get pod -n "$NS" --sort-by=.metadata.creationTimestamp -o name 2>/dev/null | grep backstage-portal-backstage | tail -1)"
POD="${POD#pod/}"
if [[ -n "$POD" ]] && oc get pod "$POD" -n "$NS" 2>/dev/null | grep -q "2/2 *Running"; then
  ok "Backstage pod is 2/2 Running ($POD)"
else
  bad "Backstage pod not 2/2 Running (still booting? re-run in a few minutes)"
fi

# 3) All X2A plugins installed (init container)
if [[ -n "$POD" ]]; then
  n=$(oc logs "$POD" -n "$NS" -c install-dynamic-plugins 2>/dev/null \
        | grep -c "Successfully installed dynamic plugin oci://ghcr.io/redhat-developer/rhdh-plugin-export-overlays/red-hat-developer-hub-backstage-plugin-x2a")
  if [[ "${n:-0}" -ge 5 ]]; then ok "All 5 X2A plugins installed (init container)"; else bad "Only ${n:-0}/5 X2A plugins installed"; fi
fi

# 4) Backend: scaffolder action registered, x2a-mcp-extras up, kube connection test PASSED
if [[ -n "$POD" ]]; then
  # Include the previous instance's log to avoid a restart race on first boot.
  LOG="$(oc logs "$POD" -n "$NS" -c backstage-backend 2>/dev/null; oc logs "$POD" -n "$NS" -c backstage-backend --previous 2>/dev/null)"
  grep -q "x2a:project:create" <<<"$LOG" && ok "scaffolder action x2a:project:create registered" || bad "x2a:project:create not found"
  grep -qiE "x2a-mcp-extras.*(KubeService initialized|Kubernetes clients created)" <<<"$LOG" && ok "x2a-mcp-extras backend initialized" || bad "x2a-mcp-extras not initialized"
  # The connection test is fatal on failure — assert it did NOT fail.
  if grep -qi "Failed to connect to namespace" <<<"$LOG"; then
    bad "kube connection test FAILED (check spec.backstage.caCertificates + SA token automount)"
  else
    ok "kube connection test passed (no connection failure; namespaced Role suffices)"
  fi
fi

# 5) CA trust wired reconcile-safely (operator injected NODE_EXTRA_CA_CERTS from caCertificates)
if oc get deploy backstage-portal-backstage -n "$NS" \
     -o jsonpath='{range .spec.template.spec.containers[?(@.name=="backstage-backend")].env[*]}{.name}{"\n"}{end}' 2>/dev/null \
     | grep -q "NODE_EXTRA_CA_CERTS"; then
  ok "NODE_EXTRA_CA_CERTS injected (spec.backstage.caCertificates wired)"
else
  bad "NODE_EXTRA_CA_CERTS not set — X2A kube TLS will fail (set spec.backstage.caCertificates)"
fi

# 6) Sign-in page overridden to github (operator default is rhaap)
if [[ -n "$POD" ]] && oc exec "$POD" -n "$NS" -c backstage-backend -- \
     grep -q "signInPage: github" /opt/app-root/src/app-config-x2a.yaml 2>/dev/null; then
  ok "auth.signInPage overridden to github (Phase-1)"
else
  bad "signInPage not overridden to github (operator default rhaap needs a reachable AAP)"
fi

# 7) Route + GitHub auth wired with a real (non-placeholder) client_id
HOST="$(oc get route backstage-portal-backstage -n "$NS" -o jsonpath='{.spec.host}' 2>/dev/null)"
if [[ -n "$HOST" ]]; then
  ok "Route present: https://$HOST"
  RID="$(curl -sk -o /dev/null -w '%{redirect_url}' "https://$HOST/api/auth/github/start?env=production&scope=read:user" 2>/dev/null)"
  CID="$(printf '%s' "$RID" | grep -oE 'client_id=[^&]+' | cut -d= -f2)"
  if [[ -n "$CID" && "$CID" != "changeme" ]]; then ok "GitHub auth redirect uses a real client_id"; else bad "GitHub auth client_id missing or still placeholder"; fi
  # 8) X2A frontend plugins served
  if grep -q "backstage-plugin-x2a" <<<"$(curl -sk "https://$HOST/api/scalprum/plugins" 2>/dev/null)"; then
    ok "X2A frontend plugins served (scalprum)"
  else
    bad "X2A frontend plugins not listed by scalprum"
  fi
else
  bad "Route not found"
fi

# 9) Conversion template registered in the operator-managed catalog.locations
if oc get cm portal-app-config -n "$NS" -o jsonpath='{.data.app-config-portal\.yaml}' 2>/dev/null \
     | grep -q "conversion-project-template.yaml"; then
  ok "X2A conversion template added to catalog.locations (via additionalTemplateURLs)"
else
  bad "X2A conversion template not in catalog.locations (set spec.plugins.catalog.additionalTemplateURLs)"
fi

echo
echo "==> $pass passed, $fail failed"
echo "In the UI (after GitHub login): expect 'Conversion Hub' in the sidebar, /x2a to render,"
echo "and 'Infrastructure Conversion Project' under Create > Choose a template."
[[ "$fail" -eq 0 ]]
