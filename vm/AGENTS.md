# Agent instructions

## Keep it simple

- Prefer obvious, editable YAML over abstractions and clever code.
- Keep Helm logic beside the setting it controls.
- No helper templates, config-merge layers, generated values or extra scripts unless requested.
- No speculative edge cases, compatibility layers or automatic migrations.
- Do not add defaults, fallback credentials or validation unless requested.
- Missing configuration may be null. Invalid configuration may fail normally.
- Do not hide errors or silently repair configuration.
- Make the smallest change needed. Explain it briefly.

## Project

Fedora bootc development VM → kind with rootful Podman → RHDH, X2A and PostgreSQL.
This is a private development setup, not production.

- `Containerfile`: builds the guest image and bundles Helm dependencies.
- `Makefile`: builds, runs and connects to the VM; renders Helm.
- `charts/x2a/`: application chart, pinned to RHDH dependency 5.12.13.
- `x2a/install.sh`: guest installation and separate `--tls-only` mode.
- `x2a/status.sh`: workload and HTTPS readiness checks.
- `systemd/`: guest startup ordering.
- `cloud-init/`: development seed.
- `README.md`: user-facing commands and limitations.

## Chart

Keep the chart source to these files; do not add helper files:

```text
charts/x2a/Chart.yaml
charts/x2a/Chart.lock
charts/x2a/values.yaml
charts/x2a/templates/rbac.yaml
charts/x2a/templates/app_config.yaml
charts/x2a/templates/dynamic-plugins.yaml
```

- Edit full app configuration directly in `app_config.yaml`.
- Edit plugin configuration directly in `dynamic-plugins.yaml`.
- Helm expressions belong in these templates, not application config in values.
- `values.yaml` holds deployment settings such as images, mounts and public URL.
- Build dependencies in temporary copies or the image, not the source tree.
- Do not reintroduce legacy credential migration or app-config overlays.

## Secrets

Use literal `KEY=value` env files without shell quotes or expansion.
Create Secrets with native `kubectl create secret generic --from-env-file`.
The installer is create-only: namespace, three explicit Secret commands, then
`helm install`. All three `/etc/x2a/{llm,aap,auth}.env` files must exist.
No loops, existence checks, updates, fallbacks, overrides or rollout restarts.
Existing resources cause normal command failure, including on later VM boots.
Deployment settings, including public URL, come from the chart, not environment files.
Do not generate Secret YAML or parse credentials in Bash.

### LLM

Inside `x2a.credentials.llm`, look up `x2a-llm` and loop over its data keys.
Forward every key as a `${KEY}` reference, never its value.
No provider allowlist, fallback keys or default model. Missing Secret → null.

### Authentication

Inside `auth.providers`, look up `x2a-auth`.

- `AUTH_GITHUB_CLIENT_ID` exists → GitHub.
- `AUTH_GITLAB_CLIENT_ID` exists → GitLab.
- `AUTH_BITBUCKET_CLIENT_ID` exists → Bitbucket.
- Use the corresponding `${AUTH_<PROVIDER>_CLIENT_ID}` and `${AUTH_<PROVIDER>_CLIENT_SECRET}` references.
- GitHub/GitLab resolver: `usernameMatchingUserEntityName`.
- Bitbucket resolver: `usernameMatchingUserEntityAnnotation`.
- Keep the requested development setting `dangerouslyAllowSignInWithoutUserInCatalog: true`.
- `signInPage` lists the enabled providers.
- No matching keys → null providers and null sign-in page.
- No enable flag, guest fallback, credential-pair validation or legacy Secret lookup.
- Import the six OAuth variables through optional references to `x2a-auth`.

## Render and check

```bash
make render                          # full manifests → render_helm.yaml
make render HELM_ARGS='--dry-run=server' # use Secrets from the current cluster
python3 -m unittest discover -s tests
make -n build run ssh stop
```

Offline rendering cannot read cluster Secrets; null sections are expected.
Lint a temporary chart copy with dependencies built when changing the chart.
Update tests and README when behavior changes. Never claim VM boot or end-to-end
success unless actually tested.

## Keep these safeguards

- Never commit real credentials, bake them into the image or serve them in the HTTP seed.
- Rendered manifests and Helm history may contain Secrets; treat them as sensitive.
- Do not expose this development VM publicly or weaken SELinux/host firewall policy.
- Preserve systemd ordering: firewalld/storage → kind → RHDH.
- Do not add a cloud-final dependency that creates a startup cycle.
- Preserve the GRUB escape in `ds=nocloud\;s=...`.
- `make run` does not rebuild or update an existing VM.
- `make stop`/`make start` preserve data; `make virt-destroy` deletes it.
- Keep HTTPS certificate generation independent of Helm.
