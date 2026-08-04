---
layout: default
title: Installation (vanilla Backstage)
parent: X2Ansible Platform
nav_order: 2
---

# Installation (vanilla Backstage)

This guide adds the X2A plugins to a stock Backstage app created with the upstream wizard, not Red Hat Developer Hub on OpenShift. For RHDH deployment, use [Installation]({% link platform/installation.md %}) instead.

Reference implementation and deeper notes live in the Red Hat plugin workspace: [rhdh-plugins/workspaces/x2a](https://github.com/redhat-developer/rhdh-plugins/tree/main/workspaces/x2a) ([`packages/app`](https://github.com/redhat-developer/rhdh-plugins/tree/main/workspaces/x2a/packages/app), [`packages/backend`](https://github.com/redhat-developer/rhdh-plugins/tree/main/workspaces/x2a/packages/backend)).

The plugins are currently tested against **Backstage 1.49.4** (conforms RHDH 1.10). Other Backstage versions may work but are not guaranteed. Since **RHDH 1.10.2**, only the New Frontend System (NFS) is supported.

## Prerequisites

Follow [Standalone Installation](https://backstage.io/docs/getting-started/) to create a new Backstage app:

```bash
npx @backstage/create-app@latest
```

Additionally, for X2A you need:

- A Kubernetes API the backend can reach (local `~/.kube/config` or in-cluster config) so migration jobs can run.
- LLM credentials and optional Ansible Automation Platform settings (see the [X2A backend plugin README](https://github.com/redhat-developer/rhdh-plugins/blob/main/workspaces/x2a/plugins/x2a-backend/README.md) for `x2a.credentials` and related environment variables).

## Install packages

From the **repository root** of your generated app (where `packages/app` and `packages/backend` live):

```bash
yarn --cwd packages/app add @red-hat-developer-hub/backstage-plugin-x2a
yarn --cwd packages/backend add @red-hat-developer-hub/backstage-plugin-x2a-backend
yarn --cwd packages/backend add @red-hat-developer-hub/backstage-plugin-scaffolder-backend-module-x2a
```

Published packages (verify versions before pinning in production):

- [@red-hat-developer-hub/backstage-plugin-x2a](https://www.npmjs.com/package/@red-hat-developer-hub/backstage-plugin-x2a) - frontend UI and scaffolder field extension exports.
- [@red-hat-developer-hub/backstage-plugin-x2a-backend](https://www.npmjs.com/package/@red-hat-developer-hub/backstage-plugin-x2a-backend) - backend API and job orchestration ([install instructions in source README](https://github.com/redhat-developer/rhdh-plugins/blob/main/workspaces/x2a/plugins/x2a-backend/README.md)).
- [@red-hat-developer-hub/backstage-plugin-scaffolder-backend-module-x2a](https://www.npmjs.com/package/@red-hat-developer-hub/backstage-plugin-scaffolder-backend-module-x2a) - scaffolder module and bundled conversion template.

### Optional components

Core X2A conversion flows do not require the packages below. Add them only when you need DCR consent UI and/or MCP tool wiring similar to the production RHDH overlays in [`deploy/app.yaml`](https://github.com/x2ansible/x2ansible.github.io/blob/main/deploy/app.yaml).

#### OAuth Dynamic Client Registration (DCR)

Since RHDH 1.10, the `/oauth2/*` consent page comes from upstream [`@backstage/plugin-auth`](https://www.npmjs.com/package/@backstage/plugin-auth) (replacing the RHDH 1.9-only `x2a-dcr` workaround):

```bash
yarn --cwd packages/app add @backstage/plugin-auth
```

Add the plugin to the NFS `features` array in `App.tsx` (see [Register the frontend plugin](#register-the-frontend-plugin)):

```tsx
import authPlugin from '@backstage/plugin-auth';

export default createApp({
  features: [
    // ...catalogPlugin, scaffolderPlugin, x2aPlugin, etc.
    authPlugin,
  ],
});
```

Enable DCR under `auth.experimentalDynamicClientRegistration` in `app-config.yaml`. For a full example, see [`deploy/app.yaml`](https://github.com/x2ansible/x2ansible.github.io/blob/main/deploy/app.yaml).

#### MCP tools

```bash
yarn --cwd packages/backend add @backstage/plugin-mcp-actions-backend
yarn --cwd packages/backend add @red-hat-developer-hub/backstage-plugin-x2a-mcp-extras
```

For `mcpActions` and related `app-config` fragments, see [MCP tools - Advanced configuration]({% link platform/mcp-server.md %}#advanced-configuration).

## Register backend plugins

In `packages/backend/src/index.ts`, register the scaffolder module and X2A backend after the base scaffolder backend ([reference `index.ts`](https://github.com/redhat-developer/rhdh-plugins/blob/main/workspaces/x2a/packages/backend/src/index.ts)):

```typescript
// ... existing backend.add(...) calls ...
backend.add(import('@backstage/plugin-scaffolder-backend'));
// Add GitHub / GitLab / Bitbucket scaffolder modules to match the auth providers you enable.
backend.add(import('@backstage/plugin-scaffolder-backend-module-github'));
backend.add(import('@backstage/plugin-scaffolder-backend-module-gitlab'));
backend.add(import('@backstage/plugin-scaffolder-backend-module-bitbucket-cloud'));
backend.add(
  import('@red-hat-developer-hub/backstage-plugin-scaffolder-backend-module-x2a'),
);
backend.add(import('@red-hat-developer-hub/backstage-plugin-x2a-backend'));
```

If you added the optional MCP packages:

```typescript
backend.add(import('@backstage/plugin-mcp-actions-backend'));
backend.add(import('@red-hat-developer-hub/backstage-plugin-x2a-mcp-extras'));
```

## Register the frontend plugin

The X2A plugin integrates with Backstage's [New Frontend System](https://backstage.io/docs/frontend-system/). In `packages/app/src/App.tsx`, import the plugin and add it to the `features` array:

```tsx
import { createApp } from '@backstage/frontend-defaults';
import catalogPlugin from '@backstage/plugin-catalog/alpha';
import scaffolderPlugin from '@backstage/plugin-scaffolder/alpha';
import userSettingsPlugin from '@backstage/plugin-user-settings/alpha';
import x2aPlugin, {
  x2aTranslationsModule,
} from '@red-hat-developer-hub/backstage-plugin-x2a/alpha';

export default createApp({
  features: [
    catalogPlugin,
    scaffolderPlugin,
    userSettingsPlugin,
    x2aPlugin,
    x2aTranslationsModule,
  ],
});
```

That is all that is needed. The plugin self-registers its `/x2a` route, sidebar entry, and scaffolder field extensions through the frontend system.

### Language configuration

To enable multi-language support, add the following to your `app-config.yaml`:

```yaml
app:
  extensions:
    - 'api:app/app-language':
        config:
          defaultLanguage: en
          availableLanguages:
            - en
            - de
            - es
            - fr
            - it
```

## Catalog: register the conversion template

In the root `app-config.yaml` (next to `packages/`), register the template shipped inside the scaffolder module. Paths are relative to this file. After `yarn install`, confirm the file exists under `node_modules`.

```yaml
catalog:
  locations:
    - type: file
      # Tweak following path based on your actual directory structure. It's relative from the perspective of `packages/backend`.
      target: ../../node_modules/@red-hat-developer-hub/backstage-plugin-scaffolder-backend-module-x2a/templates/conversion-project-template.yaml
      rules:
        - allow: [Template]
```

CSV-driven bulk flows and the `RepoAuthentication` extension are described in [CSV Bulk Import]({% link platform/csv-bulk-import.md %}).

## Configuration (pointers only)

| Topic                                                            | Where it is documented                                                                                                                                                                                                                                          |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| OAuth providers, env vars, sign-in                               | [Authentication]({% link platform/authentication.md %})                                                                                                                                                                                                         |
| RBAC / permissions for the `x2a` plugin                          | [Authorization]({% link platform/authorization.md %})                                                                                                                                                                                                           |
| `x2a:` Kubernetes image, job resources, LLM and AAP credentials  | [X2A backend plugin README](https://github.com/redhat-developer/rhdh-plugins/blob/main/workspaces/x2a/plugins/x2a-backend/README.md) and [reference app-config.yaml](https://github.com/redhat-developer/rhdh-plugins/blob/main/workspaces/x2a/app-config.yaml) |
| SCM host detection (GitHub Enterprise, self-hosted GitLab, etc.) | [Workspace README — SCM Provider Detection](https://github.com/redhat-developer/rhdh-plugins/blob/main/workspaces/x2a/README.md) (`integrations:` host entries; tokens there are not used for X2A repo auth; OAuth applies.)                                    |

If the backend API base URL seen by clients or integrations is not the default, you may need `x2a.callbackBaseUrl` (see in-cluster example in [deploy/app.yaml](https://github.com/x2ansible/x2ansible.github.io/blob/main/deploy/app.yaml)); local `yarn start` often works without it.

## Run and verify

```bash
yarn start
```

Open `http://localhost:3000/x2a` for the Conversion Hub.
In the catalog, confirm the **conversion project** template appears (might take some time to load after start-up).

## API exploration

Use [API Reference]({% link platform/api-reference.md %}) for the REST surface once the backend plugin is running.

---

## Legacy frontend system

{: .warning }
Since **RHDH 1.10.2**, only the [New Frontend System](https://backstage.io/docs/frontend-system/) (NFS) is supported.
Apps created with `npx @backstage/create-app@latest --legacy` (or otherwise using the old frontend wiring) are not supported.
Follow [Register the frontend plugin](#register-the-frontend-plugin) above.
