#!/usr/bin/env bash
# Verify the Phase-2 deployment: real AAP + native rhaap sign-in. Safe to run repeatedly.
# Does NOT print any secret values.
set -uo pipefail

NS="${NS:-automation-portal}"       # Portal namespace
AAP_NS="${AAP_NS:-aap}"             # AAP namespace
pass=0; fail=0
ok()  { echo "PASS: $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1"; fail=$((fail+1)); }

echo "==> Portal ns: $NS   AAP ns: $AAP_NS"

# 1) AAP instance reconciled + gateway pod up
if oc get ansibleautomationplatform aap -n "$AAP_NS" \
     -o jsonpath='{range .status.conditions[?(@.type=="Successful")]}{.status}{end}' 2>/dev/null | grep -q True; then
  ok "AnsibleAutomationPlatform reconciled (Successful=True)"
else
  bad "AnsibleAutomationPlatform not reconciled (Successful != True)"
fi
if oc get pods -n "$AAP_NS" --no-headers 2>/dev/null | grep aap-gateway | grep -q "2/2 *Running"; then
  ok "aap-gateway pod is 2/2 Running"
else
  bad "aap-gateway pod not 2/2 Running"
fi

# 2) Gateway route + OAuth authorize endpoint reachable
GW="$(oc get route aap -n "$AAP_NS" -o jsonpath='https://{.spec.host}' 2>/dev/null)"
if [[ -n "$GW" ]]; then
  ok "Gateway route present: $GW"
  code=$(curl -sk -o /dev/null -w '%{http_code}' "$GW/o/authorize/?response_type=code&scope=read" 2>/dev/null)
  # 302 (redirect to login) or 200 (login page) means the endpoint is served; 404 means it is not.
  if [[ "$code" == "302" || "$code" == "200" ]]; then ok "Gateway serves /o/authorize/ (http $code)"; else bad "Gateway /o/authorize/ returned http $code (expected 302/200)"; fi
else
  bad "Gateway route not found in ns $AAP_NS"
fi

# 3) secrets-rhaap-portal carries real (non-placeholder) values — checked WITHOUT printing them
HOSTURL=$(oc get secret secrets-rhaap-portal -n "$NS" -o jsonpath='{.data.aap-host-url}' 2>/dev/null | base64 -d 2>/dev/null)
if [[ -n "$HOSTURL" && "$HOSTURL" != *"placeholder.invalid"* ]]; then ok "aap-host-url is real (not the placeholder)"; else bad "aap-host-url still points at the placeholder"; fi
for k in oauth-client-id oauth-client-secret aap-token; do
  v=$(oc get secret secrets-rhaap-portal -n "$NS" -o jsonpath="{.data.$k}" 2>/dev/null | base64 -d 2>/dev/null)
  if [[ -n "$v" && "$v" != "changeme"* && "$v" != "placeholder"* && "$v" != "your-"* ]]; then ok "$k is set to a real value"; else bad "$k is empty or still a placeholder"; fi
done

# 4) Phase-1 sign-in override is GONE (operator default rhaap is in effect)
POD="$(oc get pod -n "$NS" --sort-by=.metadata.creationTimestamp -o name 2>/dev/null | grep backstage-portal-backstage | tail -1)"; POD="${POD#pod/}"
if [[ -n "$POD" ]] && oc exec "$POD" -n "$NS" -c backstage-backend -- grep -q "signInPage: github" /opt/app-root/src/app-config-x2a.yaml 2>/dev/null; then
  bad "overlay still forces signInPage: github (apply phase2/02-app-config-x2a-rhaap.configmap.yaml)"
else
  ok "no signInPage:github override — operator default rhaap in effect"
fi

# 5) rhaap /start redirects to the real gateway with a real client_id
HOST="$(oc get route backstage-portal-backstage -n "$NS" -o jsonpath='{.spec.host}' 2>/dev/null)"
if [[ -n "$HOST" ]]; then
  RID="$(curl -sk -o /dev/null -w '%{redirect_url}' "https://$HOST/api/auth/rhaap/start?env=production&scope=read" 2>/dev/null)"
  if grep -q "/o/authorize/" <<<"$RID" && ! grep -q "placeholder" <<<"$RID"; then
    ok "rhaap /start redirects to the real gateway /o/authorize/"
  else
    bad "rhaap /start does not target a real gateway (got: ${RID:-<none>})"
  fi
  CID="$(printf '%s' "$RID" | grep -oE 'client_id=[^&]+' | cut -d= -f2)"
  if [[ -n "$CID" && "$CID" != "placeholder" ]]; then ok "rhaap redirect carries a real client_id"; else bad "rhaap redirect client_id missing or placeholder"; fi
else
  bad "Portal route not found"
fi

# 6) No recent 'Failed to create user' / rhaap Unauthorized in the backend log
if [[ -n "$POD" ]]; then
  if oc logs "$POD" -n "$NS" -c backstage-backend --tail=500 2>/dev/null | grep -qiE "Failed to create user|Failed to fetch user details"; then
    bad "backend log shows a user-creation failure (aap-token invalid/expired? re-run Step 5)"
  else
    ok "no user-creation failures in the recent backend log"
  fi
fi

echo
echo "==> $pass passed, $fail failed"
echo "Final check is manual: open the Portal, click 'Sign in using Ansible Automation Platform',"
echo "log into the gateway, and confirm you land in the Portal as your AAP user."
[[ "$fail" -eq 0 ]]
