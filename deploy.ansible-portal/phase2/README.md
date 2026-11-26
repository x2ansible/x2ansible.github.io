# Phase 2 — real AAP behind the Portal + native `rhaap` sign-in

This extends the [Phase-1 guide](../README.md) (Automation Portal operator + X2A, GitHub sign-in,
placeholder AAP) to a **real [Ansible Automation Platform 2.7](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/)**
instance so the Portal signs in through its **native `rhaap`** provider — no GitHub override.
Confirmed working end-to-end on a live cluster. Product background:
[Configure credentials and secrets for the automation portal operator](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-configure_credentials_and_secrets_for_the_automation_portal_operator)
and the [Phase-1 official documentation table](../README.md#official-documentation-red-hat-aap-27).

At the end, opening the Portal shows **"Sign in using Ansible Automation Platform"**, which
redirects to the AAP gateway login, and after consent you land in the Portal as an AAP-backed user.

## Prerequisites

- A completed Phase-1 deployment (the `AutomationPortal` CR, the `secrets-rhaap-portal` secret with
  its four keys, and the X2A overlay are already in place).
- An **AAP subscription entitlement** on your Red Hat account — a free **60-day AAP trial**
  (redhat.com Ansible trial) or a **Red Hat Developer** subscription is enough. Check
  `console.redhat.com/insights/subscriptions/inventory` (filter "ansible"). You do **not** need to
  build a subscription-manifest `.zip` for this lab — the gateway subscription wizard can attach an
  entitlement with your Red Hat login at first launch (see Step 3 and
  [Activate your subscription](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-assembly_aap_activate_1)).
  *(Optional manifest upload:
  [Activate with a manifest file](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-proc_aap_activate_with_manifest).
  The legacy `access.redhat.com` allocations page is retired; the current manifest tool is
  `console.redhat.com/insights/subscriptions/manifests`. Activation keys register RHEL hosts, not
  AAP.)*
- The cluster's entitled `registry.redhat.io` pull credential (already used in Phase 1) — the AAP
  images pull from there.

## The two credentials `rhaap` sign-in needs (read this first)

This is the part that is easy to get wrong. The Portal's `rhaap` provider needs **two independent
credentials**, both stored in `secrets-rhaap-portal`:

| Secret key | What it is | Used for |
|---|---|---|
| `oauth-client-id` / `oauth-client-secret` | An **OAuth Application** in the AAP gateway | The interactive **sign-in** flow (`/o/authorize/` → `/o/token/`) |
| `aap-token` | A **gateway API token** (personal access token) | The **catalog provider** (`AapEntityProvider`) that creates your Backstage user by reading `/api/gateway/v1/users|organizations|teams` |

If only the OAuth Application is set and `aap-token` is left as a placeholder, sign-in **appears to
authenticate but then fails** with:

```
Login failed; Failed to create user: Failed to fetch user details for admin (ID: 2): Failed to fetch data.
```

The backend log shows the OAuth token exchange succeeding, then `GET /api/gateway/v1/users/2/`
returning **Unauthorized** — because the catalog provider authenticates with `aap-token`, not the
user's OAuth token. Setting a real `aap-token` (Step 5) fixes it.

The operator's generated `rhaap` config is entirely **runtime env-substituted** from this secret
(`clientId: ${OAUTH_CLIENT_ID}`, `host: ${AAP_HOST_URL}`, `token: ${AAP_TOKEN}`), so changing the
secret needs **only a pod restart** — no operator reconcile. Red Hat documents the same four
`secrets-rhaap-portal` keys and redirect URI
`…/api/auth/rhaap/handler/frame` in
[Configure credentials and secrets for the automation portal operator](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-configure_credentials_and_secrets_for_the_automation_portal_operator).
Use a **read**-scope `aap-token` for the catalog provider (Step 5).

## Step 1 — Install the AAP operator

```bash
oc apply -f phase2/00-aap-operator.yaml           # ns `aap`, channel stable-2.7, redhat-operators
oc get csv -n aap | grep -i aap-operator          # wait for Succeeded
```

See [Install Ansible Automation Platform Operator from the CLI](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-assembly_installing_aap_operator_cli)
(channel `stable-2.7`, namespace-scoped operator).

## Step 2 — Deploy a minimal AAP instance

```bash
oc apply -f phase2/01-aap-instance.yaml            # gateway + controller; hub/eda/lightspeed disabled
```

Gateway + controller + a managed PostgreSQL + Redis come up (Hub/EDA/Lightspeed are disabled to fit
a lab — the sign-in flow only needs the gateway). Field reference:
[`AnsibleAutomationPlatform` CR (aap.ansible.com/v1alpha1)](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/reference-ansibleautomationplatform__aap_ansible_com_v1alpha1_).
Give it 5–10+ minutes and several large image pulls. Wait for the gateway:

```bash
oc get ansibleautomationplatform aap -n aap -o jsonpath='{range .status.conditions[?(@.type=="Successful")]}{.message}{end}{"\n"}'
oc get pods -n aap | grep -E "aap-gateway|aap-controller|aap-postgres"   # aap-gateway should be 2/2 Running
oc get route aap -n aap -o jsonpath='https://{.spec.host}{"\n"}'          # the gateway URL
```

## Step 3 — First login + attach the subscription

```bash
# gateway admin password (auto-generated):
oc get secret aap-admin-password -n aap -o jsonpath='{.data.password}' | base64 -d; echo
```

Open the gateway route, log in as **`admin`** with that password. On the subscription screen choose
**"I have a Red Hat account"**, sign in, and select your **AAP entitlement** (e.g. the 60-day
trial). Accept the EULA. See
[Get started as a platform administrator](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/get_started-assembly_gs_platform_admin)
(first login / subscription).

## Step 4 — Create the OAuth Application (for sign-in)

In the gateway UI: **Access Management → OAuth Applications → Create OAuth application** (see
[Create an OAuth application](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-proc_self_service_create_oauth_app)):

| Field | Value |
|---|---|
| Name | `RHDH Portal` (any) |
| Organization | `Default` |
| Authorization grant type | **Authorization code** |
| Client type | **Confidential** |
| Redirect URIs | `https://backstage-portal-backstage-automation-portal.apps.<cluster-domain>/api/auth/rhaap/handler/frame` |

Save and copy the **Client ID** and the **one-time Client Secret**.

## Step 5 — Create a gateway API token (for the catalog provider)

In AAP 2.7 all user tokens are created through the **platform gateway** (not automation controller);
see [Personal Access Token removal in AAP 2.7](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/secure-con_pat_removal_27)
and [OAuth 2 token authentication](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/secure-con_controller_api_oauth2_token).
The token endpoint is `/api/gateway/v1/tokens/` (documented in the
[platform gateway OpenAPI specification](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/configure-con_gw_open_api_specification);
the controller's old `/api/v2/tokens/` is gone in AAP 2.5+). Create a **read-scope** personal access
token as `admin` and store it in a shell variable (so it is never printed). Wire it into
`secrets-rhaap-portal` in Step 6 and restart the Backstage pod in Step 7. Replace `<PASSWORD>`
(gateway admin password) and set `GW` to your gateway URL:

```bash
export KUBECONFIG=<your-kubeconfig>
GW=https://aap-aap.apps.<cluster-domain>
TOKEN=$(curl -sk -u admin:'<PASSWORD>' -X POST "$GW/api/gateway/v1/tokens/" \
          -H 'Content-Type: application/json' \
          -d '{"description":"RHDH catalog provider","scope":"read"}' \
        | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
echo "token length: ${#TOKEN}"     # expect a non-zero number
```

*(You can also create the token in the UI: **Access Management → Users → admin → Tokens → Create token**
with **Read** scope — see
[Configure access to external applications with tokens](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/secure-assembly_gw_token_based_authentication).)*

## Step 6 — Wire the four values into `secrets-rhaap-portal`

`oauth-client-id` / `oauth-client-secret` come from Step 4; `aap-host-url` is the gateway route;
`aap-token` from Step 5. If you ran the Step-5 command with `$TOKEN` still in your shell, the
patch + restart is folded in below:

```bash
oc patch secret secrets-rhaap-portal -n automation-portal --type merge -p '{"stringData":{
  "aap-host-url":"https://aap-aap.apps.<cluster-domain>",
  "oauth-client-id":"<CLIENT_ID>",
  "oauth-client-secret":"<CLIENT_SECRET>"
}}'
# and the token (from Step 5, token still in $TOKEN):
[ -n "$TOKEN" ] && oc patch secret secrets-rhaap-portal -n automation-portal --type merge \
  -p "{\"stringData\":{\"aap-token\":\"$TOKEN\"}}"
```

## Step 7 — Switch sign-in to native `rhaap` and restart

Apply the Phase-2 overlay, which is the Phase-1 `app-config-x2a` **minus** the `signInPage: github`
override and the github resolver — so the operator's default `auth.signInPage: rhaap` stands:

```bash
oc apply -f phase2/02-app-config-x2a-rhaap.configmap.yaml
oc rollout restart deploy backstage-portal-backstage -n automation-portal
```

Wait for the pod to return to `2/2 Running` (the plugin init container re-runs; a few minutes).

## Step 8 — Verify

```bash
NS=automation-portal AAP_NS=aap ./scripts/verify-phase2.sh
```

Then open the Portal and sign in with **"Sign in using Ansible Automation Platform"** → gateway
login → consent → you land in the Portal. The backend log should show
`listProjects called by user:default/<you>` and permission checks resolving to `ALLOW` (proof the
user entity was created from AAP).

## Reverting to Phase 1

Re-apply `../manifests/03-app-config-x2a.configmap.yaml` (restores the `signInPage: github`
override) and restart the pod. The AAP instance can stay up or be removed
(`oc delete ansibleautomationplatform aap -n aap`).

## Official documentation (Red Hat, AAP 2.7 — Phase 2)

| Topic | Reference |
| --- | --- |
| Portal ↔ AAP credentials (`secrets-rhaap-portal`, OAuth redirect) | [Configure credentials and secrets](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-configure_credentials_and_secrets_for_the_automation_portal_operator) |
| AAP operator on OpenShift (`stable-2.7`) | [Install AAP operator (CLI)](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-assembly_installing_aap_operator_cli) |
| `AnsibleAutomationPlatform` CR | [API reference](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/reference-ansibleautomationplatform__aap_ansible_com_v1alpha1_) |
| Subscription at first login | [Activate your subscription](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-assembly_aap_activate_1) |
| OAuth application for portal sign-in | [Create an OAuth application](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-proc_self_service_create_oauth_app) |
| Gateway tokens (2.7) | [PAT removal](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/secure-con_pat_removal_27), [OAuth 2 tokens](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/secure-con_controller_api_oauth2_token), [Gateway OpenAPI](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/configure-con_gw_open_api_specification) |
| Phase 1 + operator overlays | [Parent guide](../README.md), [operator configuration reference](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-automation_portal_operator_configuration_reference) |

## Files

```
phase2/
  README.md                              this Phase-2 runbook
  00-aap-operator.yaml                   AAP operator Subscription (ns aap, stable-2.7)
  01-aap-instance.yaml                   AnsibleAutomationPlatform CR (gateway+controller; hub/eda/lightspeed off)
  02-app-config-x2a-rhaap.configmap.yaml app-config-x2a WITHOUT the Phase-1 sign-in override
../scripts/verify-phase2.sh              Phase-2 checks (AAP up, secret real, rhaap redirect, gateway /o/authorize)
```
