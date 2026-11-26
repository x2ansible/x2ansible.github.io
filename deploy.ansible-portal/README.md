# Install X2A on the Automation Portal operator (OpenShift)

A repeatable, CLI-first path to run the **X2A** plugins (Conversion Hub) inside the RHDH instance
that the **[Ansible Automation Portal operator](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/whats_new-automation_portal_operator)**
([AAP 2.7](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/), Technology Preview) manages — **without a full
AAP behind it** (Phase 1). Sign-in is handled by a **GitHub OAuth App**.

> Here, the **Automation Portal operator owns and regenerates** the `Backstage` CR and
> the `portal-app-config` / `portal-dynamic-plugins` ConfigMaps, so you must **never hand-edit
> them** — you extend the Portal through the operator's reconcile-safe merge fields instead.
> See [Understand the automation portal operator](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-understand_the_automation_portal_operator)
> and the [`AutomationPortal` configuration reference](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-automation_portal_operator_configuration_reference).

## What you get

X2A runs in the Portal's RHDH web UI: a **Conversion Hub** page (`/x2a`) and an **Infrastructure
Conversion Project** scaffolder template that converts infrastructure definitions into Ansible and
(day-2) publishes them to AAP.

## Phasing

- **Phase 1 (this guide): Automation Portal operator + X2A only, no full AAP.** Confirmed to work:
  the operator reconciles to fully Ready with a **placeholder** `aap` secret (it validates the
  secret's shape, not the host's reachability), and browser sign-in uses **GitHub OAuth**.
- **Phase 2 ([`phase2/`](./phase2/README.md)): add a real AAP 2.7** and switch sign-in to the
  native `rhaap` provider. Drop the Phase-1 `signInPage` override and give `secrets-rhaap-portal`
  real values. **Confirmed working end-to-end**. The `rhaap` sign-in needs
  **two** credentials (an OAuth Application *and* a gateway API token); see the Phase-2 guide.

## Prerequisites

- OpenShift **4.18+** ([supported for the portal operator](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-install_automation_portal_on_openshift_container_platform)); `oc` logged in as **cluster-admin**.
- Cluster access to the **`redhat-operators`** catalog (for the RHDH and Automation Portal
  operators) and egress to **`ghcr.io`**, **`quay.io/x2ansible`**, and **`registry.redhat.io`**.
- **Entitled `registry.redhat.io` pull credentials** — the operator's bundled plugins pull from
  there. `deploy.sh` reuses the cluster's global pull-secret by default (see [Updating the global cluster pull secret](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/images/managing-images#images-update-global-pull-secret_managing-images), OCP 4.18).
- A **GitHub OAuth App** (created below) — required for sign-in.
- Optional (day-2 conversions only): a GitHub token for SCM push/PR, an LLM/Bedrock credential,
  and — for Phase 2 — an AAP OAuth token + org.

## RHDH 1.10 requirement

The X2A OCI overlays are tagged `bs_1.49.4__*` and require **RHDH 1.10** (productized Backstage
1.49.4). The Automation Portal operator pulls RHDH via the `rhdh` operator's `fast` channel, which
currently resolves to **v1.10.x** (default portal image tag `1.10` in the
[`AutomationPortal` CR](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-automation_portal_operator_configuration_reference)).
If it resolves to something else, stop and reconcile the version before continuing.

| RHDH resolved by the Portal | Action |
|---|---|
| **1.10.x** | Proceed |
| 1.9.x | Stop — overlays would need `bs_1.45.3` tags |
| 1.11+ | Stop and re-verify — these tags may not load |

## How the reconcile-safe overlay works

The operator regenerates the `Backstage` CR and its ConfigMaps every reconcile. You extend it only
through these `AutomationPortal` spec fields (all used in `manifests/01-automationportal.yaml`; field
semantics are defined in the
[operator configuration reference](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-automation_portal_operator_configuration_reference)):

| Field | ConfigMap / Secret | What it does |
|---|---|---|
| `spec.plugins.customPluginsRef` | `x2a-dynamic-plugins` | Dynamic plugins **merged** on top of the base plugin set |
| `spec.plugins.customAppConfigRef` | `app-config-x2a` | App-config **loaded last** — scalars win, objects deep-merge |
| `spec.backstage.caCertificates.secretRef` | `x2a-ca-bundle` | CA bundle the operator mounts + wires as `NODE_EXTRA_CA_CERTS` |
| `spec.plugins.catalog.additionalTemplateURLs` | — | Extra Template URLs **appended** to `catalog.locations` |

Never edit `portal-app-config`, `portal-dynamic-plugins`, or the `Backstage` CR directly — those
edits are reverted on the next reconcile. (This was confirmed live: a direct env patch to the
`Backstage` CR's backstage-backend container vanished on reconcile, which is why the CA trust goes
through `spec.backstage.caCertificates` instead; see
[Configure custom TLS certificates for the automation portal operator](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-configure_custom_tls_certificates_for_the_automation_portal_operator).)

## Step 1 — Create the GitHub OAuth App

Phase 1 uses GitHub for **sign-in** because there is no reachable AAP gateway yet. Red Hat documents
GitHub on the `AutomationPortal` CR primarily for SCM integration (not the default sign-in page); this
guide adds a reconcile-safe `app-config` override — see
[Configure SCM provider authentication](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-configure_authentication_providers_for_the_automation_portal_operator)
and [RHDH 1.10 — share GitHub OAuth credentials](https://docs.redhat.com/en/documentation/red_hat_developer_hub/1.10/html/authentication_in_red_hat_developer_hub/share-a-secret-with-your-identity-provider_authentication-in-rhdh).

The route host is deterministic:
`backstage-portal-backstage-<namespace>.apps.<cluster-domain>`
(get the domain with `oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'`).
With the default namespace `automation-portal` you can create the app up front.

On **github.com → Settings → Developer settings → OAuth Apps → New OAuth App**:

| Field | Value |
|---|---|
| **Application name** | any label, e.g. `X2A on Ansible Portal` |
| **Homepage URL** | `https://backstage-portal-backstage-automation-portal.apps.<cluster-domain>` |
| **Authorization callback URL** | `https://backstage-portal-backstage-automation-portal.apps.<cluster-domain>/api/auth/github/handler/frame` |

Then **Generate a client secret**. Keep the **Client ID** and **Client Secret**.

## Step 2 — Fill in the secrets

Required AAP-shaped keys in `secrets-rhaap-portal` (placeholder values are fine for Phase 1) match
[Configure credentials and secrets for the automation portal operator](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-configure_credentials_and_secrets_for_the_automation_portal_operator).

```bash
cd deploy.ansible-portal
cp manifests/05-secrets.yaml.example manifests/05-secrets.yaml
# edit manifests/05-secrets.yaml:
#   x2a-github-oauth   client-id / client-secret   <- from Step 1 (required)
#   secrets-rhaap-portal  (placeholder AAP)         <- leave as-is for Phase 1
```

The real `05-secrets.yaml` is gitignored; only the `.example` is committed. The `x2a-ca-bundle`
and `portal-registry-auth` secrets are built for you by `deploy.sh`.

## Step 3 — Deploy

```bash
NS=automation-portal ./scripts/deploy.sh
```

Equivalent product flow: [Install the automation portal operator](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-install_the_automation_portal_operator)
and [Install automation portal on OpenShift using the operator](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-install_automation_portal_on_openshift_using_the_operator).

This installs both operators (and waits for their CSVs), builds the CA-bundle and registry-auth
secrets, applies the X2A overlay ConfigMaps + RBAC + your app secrets, applies the
`AutomationPortal` CR, waits for `Ready`, and prints the route + callback URL.

> **Shared clusters:** `deploy.sh` always applies the RHDH `Subscription` in `openshift-operators`
> (`channel: fast`). If RHDH is already installed with a different channel or version, reconcile that
> with your cluster owners before running deploy — OLM may upgrade or conflict with the existing CSV.

> **First boot is slow and may restart once or twice — this is expected.** The plugin set plus the
> bundled ~5 GB `lightspeed-core` RAG sidecar can take several minutes and occasionally exceed
> RHDH's default startup probe. It converges on its own; no probe change is needed. Wait for the
> pod to reach `2/2 Running`.

### Registry-auth gotcha (built in to `deploy.sh`)

The operator's `install-dynamic-plugins` init container uses **skopeo**, which looks for a file
named **`auth.json`**. A plain `.dockerconfigjson`-only secret makes the operator's *own* bundled
plugin pulls fail with `unauthorized`. `deploy.sh` therefore creates `portal-registry-auth` as an
**Opaque** secret carrying the key `auth.json` (and `.dockerconfigjson` too). Override the source
credentials with `REG_AUTH_FILE=<path-to-docker-config-json>`. This matches step 7 in
[Configure credentials and secrets for the automation portal operator](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-configure_credentials_and_secrets_for_the_automation_portal_operator)
(`portal-registry-auth`, mounted for skopeo OCI plugin pulls).

## Step 4 — Verify

```bash
NS=automation-portal ./scripts/verify.sh
```

All 13 checks should pass:

- `AutomationPortal` `Ready=True` and `BackstageReady=True`; pod `2/2 Running`.
- All 5 X2A plugins installed; backend registered `x2a:project:create`; `x2a-mcp-extras`
  initialized; **kube connection test passed** (namespaced Role only — no ClusterRole).
- `NODE_EXTRA_CA_CERTS` injected (CA trust wired); `auth.signInPage` overridden to `github`.
- Route present; GitHub auth redirect uses a **real** `client_id`; X2A frontend served (scalprum).
- Conversion template registered in `catalog.locations`.

Then open the route, **log in with GitHub**, and confirm:

- **Conversion Hub** appears in the sidebar; `/x2a` renders.
- Under **Create → Choose a template**, **Infrastructure Conversion Project** is listed. (The
  catalog API can't be queried headlessly, so this final check is visual — the location is
  registered and reads without error, and the template is self-contained YAML.)

## Why sign-in needs an override (important)

Enabling `spec.auth.providers.github` wires GitHub as an auth *provider*, but the operator also
**hardwires `auth.signInPage: rhaap`** — the sign-in *page* targets the AAP gateway, which does not
exist in Phase 1 — and the generated GitHub provider has **no sign-in resolver**. Red Hat notes that
GitHub/GitLab providers configured on the CR are for SCM integration and do not appear on the sign-in
page by default ([SCM provider authentication](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-configure_authentication_providers_for_the_automation_portal_operator)).
So `manifests/03-app-config-x2a.configmap.yaml` (loaded last via `customAppConfigRef`) sets
`auth.signInPage: github` and deep-merges a `signIn.resolvers` entry (pattern from
[RHDH 1.10 authentication](https://docs.redhat.com/en/documentation/red_hat_developer_hub/1.10/html/authentication_in_red_hat_developer_hub/enable-authentication-with-your-identity-provider_authentication-in-rhdh)).
In Phase 2, remove that override and use native `rhaap` sign-in — see [`phase2/`](./phase2/README.md)
and [portal credentials / OAuth redirect URI](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-configure_credentials_and_secrets_for_the_automation_portal_operator).

### Phase-1 auth settings (lab / evaluation only)

The Phase-1 `app-config-x2a` overlay enables `dangerouslyAllowSignInWithoutUserInCatalog` (GitHub
sign-in without a catalog `User` entity) and broad Dynamic Client Registration redirect patterns (including `http://*`). That keeps the eval path simple; **do not reuse these settings unchanged in production** — tighten resolvers, catalog import, and DCR allow-lists for your identity model.

## Day-2 — running conversions

Conversions need real values via the `x2a:` block in `app-config-x2a` (env-substituted with
`${VAR:-default}`), supplied as extra env on the deployment or a secret you reference:

| Capability | Needs |
|---|---|
| Run conversion Jobs | healthy X2A backend + the namespaced RBAC (already applied) |
| LLM conversion | real `LLM_MODEL` / `AWS_REGION` / `AWS_BEARER_TOKEN_BEDROCK` (or your provider) |
| Push / PR | a GitHub token with repo scope |
| Publish to AAP | real `AAP_URL` + `AAP_OAUTH_TOKEN` + `AAP_ORG_NAME` (Phase 2) |

## Official documentation (Red Hat, AAP 2.7)

| Topic | Reference |
| --- | --- |
| Automation Portal operator (overview, Tech Preview) | [What's new — Automation portal operator](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/whats_new-automation_portal_operator) |
| OpenShift install paths (operator vs Helm) | [Install automation portal on OpenShift](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-install_automation_portal_on_openshift_container_platform) |
| Operator install + `AutomationPortal` CR | [Install the automation portal operator](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-install_the_automation_portal_operator) |
| Secrets, OAuth app, registry auth (`auth.json`) | [Configure credentials and secrets](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-configure_credentials_and_secrets_for_the_automation_portal_operator) |
| CR fields (`customPluginsRef`, `customAppConfigRef`, status) | [Automation portal operator configuration reference](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-automation_portal_operator_configuration_reference) |
| Private CA / `NODE_EXTRA_CA_CERTS` | [Configure custom TLS certificates (operator)](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-configure_custom_tls_certificates_for_the_automation_portal_operator) |
| Air-gapped clusters | [Deploy automation portal in disconnected environments](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-deploy_automation_portal_in_disconnected_environments) |
| Phase 2 — AAP on OpenShift | [Install AAP operator (CLI)](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-assembly_installing_aap_operator_cli), [`AnsibleAutomationPlatform` CR](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/reference-ansibleautomationplatform__aap_ansible_com_v1alpha1_) |
| RHDH sign-in (Phase 1 GitHub override) | [Authentication in RHDH 1.10](https://docs.redhat.com/en/documentation/red_hat_developer_hub/1.10/html-single/authentication_in_red_hat_developer_hub/index) |

## Files

```
deploy.ansible-portal/
  README.md                                   this guide
  manifests/
    00-operators.yaml                         RHDH + Automation Portal operator subscriptions
    01-automationportal.yaml                  the AutomationPortal CR (all reconcile-safe overlay refs)
    02-x2a-dynamic-plugins.configmap.yaml     customPluginsRef: X2A dynamic plugins (pinned)
    03-app-config-x2a.configmap.yaml          customAppConfigRef: X2A app-config + sign-in override
    04-namespace-rbac.yaml                    namespaced Role + RoleBinding to the `default` SA
    05-secrets.yaml.example                   GitHub OAuth + placeholder AAP (copy to .yaml, fill, gitignored)
  scripts/
    deploy.sh                                 install operators, build secrets, apply overlay + CR
    verify.sh                                 13 checks: CR/pod/plugins/kube/CA/sign-in/route/frontend/template
    verify-phase2.sh                          Phase-2 checks: AAP up, real secret, rhaap redirect, /o/authorize
  phase2/                                     Phase 2 — real AAP + native rhaap sign-in
    README.md                                 Phase-2 runbook (the two-credential model)
    00-aap-operator.yaml                      AAP operator Subscription (ns aap, stable-2.7)
    01-aap-instance.yaml                      AnsibleAutomationPlatform CR (gateway+controller; hub/eda/lightspeed off)
    02-app-config-x2a-rhaap.configmap.yaml    app-config-x2a WITHOUT the Phase-1 sign-in override
```

## Support status

- The **X2A plugins are community overlays** — pinned builds from
  `ghcr.io/redhat-developer/rhdh-plugin-export-overlays` (nightly `quay.io/x2ansible` alternative).
- The **Automation Portal operator is Tech Preview** ([product documentation](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/install-set_up_the_automation_portal_operator)).
- **This is not a Red Hat-supported product stack.** Use for evaluation/development only.

