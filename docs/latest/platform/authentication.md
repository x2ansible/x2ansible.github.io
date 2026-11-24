---
layout: default
title: Authentication
parent: X2Ansible Platform
nav_order: 3
---

# Authentication

The X2Ansible UI uses OAuth-based authentication through Backstage's authentication framework. Users sign in via their Git provider accounts (GitHub, GitLab, or Bitbucket).

## Overview

Authentication serves two purposes in X2Ansible:

1. **User Identity**: Identifies who is accessing the system
2. **Source Control Access**: Provides OAuth tokens for reading/writing Git repositories

## Supported Providers

### GitHub

**Configuration** in `app-config.yaml`:

```yaml
auth:
  providers:
    github:
      development:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: usernameMatchingUserEntityName
```

**Setup**:
1. Create a GitHub OAuth application at [github.com/settings/developers](https://github.com/settings/developers)
2. Set the callback URL to `http://localhost:7007/api/auth/github/handler/frame` (development) or your production URL
3. Copy the Client ID and Client Secret to environment variables

**Required Scopes**: Automatically configured by Backstage (includes `repo`, `user`)

### GitLab

**Configuration** in `app-config.yaml`:

```yaml
auth:
  providers:
    gitlab:
      development:
        clientId: ${AUTH_GITLAB_CLIENT_ID}
        clientSecret: ${AUTH_GITLAB_CLIENT_SECRET}
        audience: https://gitlab.com
        signIn:
          resolvers:
            - resolver: usernameMatchingUserEntityName
```

**Setup**:
1. Create a GitLab OAuth application at [gitlab.com/-/user_settings/applications](https://gitlab.com/-/user_settings/applications)
2. Set the redirect URI to `http://localhost:7007/api/auth/gitlab/handler/frame`
3. Request scopes: `api`, `read_user`, `read_api`, `read_repository`, `write_repository`, `openid`, `profile`, `email`
4. Copy the Application ID and Secret to environment variables

**Required Scopes** (per [Backstage documentation](https://backstage.io/docs/auth/gitlab/provider/) and the X2Ansible repository picker):
- `api` (the repository picker's token carries the scopes of the app's `scmAuthApi`, which needs `api`)
- `read_user`
- `read_api`
- `read_repository`
- `write_repository`
- `openid`, `profile`, `email`

### Bitbucket

**Configuration** in `app-config.yaml`:

```yaml
auth:
  providers:
    bitbucket:
      development:
        clientId: ${AUTH_BITBUCKET_CLIENT_ID}
        clientSecret: ${AUTH_BITBUCKET_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: usernameMatchingUserEntityAnnotation
```

**Setup**:
1. Create a [Bitbucket OAuth consumer](https://support.atlassian.com/bitbucket-cloud/docs/use-oauth-on-bitbucket-cloud/) at `https://bitbucket.org/<workspace>/workspace/settings/oauth-clients`
2. Set the callback URL to `http://localhost:7007/api/auth/bitbucket`
3. Request the following scopes:
   - `account:read`
   - `workspace membership:read`
   - `project:read`
   - `snippet:write`
   - `issue:write`
   - `pullrequest:write`
4. Copy the Key (Client ID) and Secret to environment variables

**Note**: Bitbucket uses `usernameMatchingUserEntityAnnotation` resolver instead of `usernameMatchingUserEntityName`.

## SCM hosts and authHosts

The conversion project template offers the GitHub and GitLab hosts listed under `integrations:` (plus `bitbucket.org`) in its repository pickers, so self-hosted GitLab and GitHub Enterprise instances work without editing the template. Add the instance to `integrations:`, configure the matching auth provider as shown above, and set `x2a.scm.authHosts` (below); hosts not named there are left out of the picker.

{: .warning }
**Breaking change (plugins 2.1.0):** `x2a.scm.authHosts` is required and has **no default**, not even for `github.com` or `gitlab.com`. Until it is set, running phases, bulk runs, the CSV bulk import and the repository picker refuse every GitHub or GitLab host with an error naming the missing key.

Backstage auth providers are configured once per provider type, so the OAuth token they issue is valid for a single host. X2Ansible therefore hands a token only to the host named in `x2a.scm.authHosts`:

```yaml
x2a:
  scm:
    authHosts:
      github: github.com             # or the host of auth.providers.github.<env>.enterpriseInstanceUrl
      gitlab: gitlab.example.com     # the host of auth.providers.gitlab.<env>.audience
```

- The value is a bare host or a URL (the GitLab `audience` can be copied as is). A non-default port is part of the host (`gitlab.example.com:8443`).
- Bitbucket Cloud is always `bitbucket.org` and needs no entry.
- Keeping `authHosts` in sync with the auth provider configuration is up to you; the frontend cannot verify it.
- RHDH 1.10 maps every `integrations:` host to the auth provider of its type out of the box. Newer RHDH releases do this through the `app-integrations` plugin: keep it enabled (it is by default), otherwise custom hosts get a sign-in error and no token. Other Backstage apps must register `ScmAuth.forGitlab(api, { host })` (or the GitHub equivalent) for custom hosts.
- RHDH dynamic plugin deployments must list `X2ARepoUrlPickerExtension` in `scaffolderFieldExtensions` (see [`deploy/app.yaml`](https://github.com/x2ansible/x2ansible.github.io/blob/main/deploy/app.yaml)); otherwise the repository fields silently become plain text inputs.
- Only one GitHub, one GitLab and one Bitbucket Cloud host can be authenticated at a time. Azure, Gerrit, Gitea and Bitbucket Server are not offered.

For the full behavior and limitations see [SCM hosts and the X2ARepoUrlPicker field](https://github.com/redhat-developer/rhdh-plugins/blob/main/workspaces/x2a/docs/scm-hosts.md).

## Sign-In Resolvers

Sign-in resolvers map OAuth user identities to Backstage user entities:

| Resolver | Provider | Behavior |
|----------|----------|----------|
| `usernameMatchingUserEntityName` | GitHub, GitLab | Matches OAuth username to Backstage user entity name |
| `usernameMatchingUserEntityAnnotation` | Bitbucket | Matches OAuth username to Backstage user annotation |

## Guest User (Development Only)

For local development without OAuth setup, enable the guest provider:

```yaml
auth:
  environment: development
  providers:
    guest: {}
```

The guest user (`user:development/guest`) has limited permissions and is **not recommended for production**.

## User Management

Red Hat Developer Hub provides multiple ways to manage users in the catalog:

### Option 1: Automatic User Import from Git Providers (Recommended)

The recommended approach is to use **catalog provider plugins** to automatically import users and groups from your Git provider organization. This provides one-way synchronization where user and group data flow from your identity provider to the Developer Hub software catalog.

#### GitHub Organization Import

Enable the GitHub catalog provider to automatically import users and groups:

**Configuration in `app-config.yaml`:**

```yaml
catalog:
  providers:
    github:
      providerId:
        organization: 'your-github-org'
        catalogPath: '/catalog-info.yaml'
        filters:
          branch: 'main'
        schedule:
          frequency:
            minutes: 30
          timeout:
            minutes: 3
```

**Required Configuration:**
1. GitHub OAuth app configured in `auth.providers.github`
2. GitHub integration configured in `integrations.github`
3. GitHub catalog provider plugin enabled in `dynamic-plugins.yaml`

**What gets imported:**
- All users from your GitHub organization
- All teams as groups
- User-to-group relationships (team memberships)

See: [Integrating Red Hat Developer Hub with GitHub](https://docs.redhat.com/en/documentation/red_hat_developer_hub/1.7/html-single/integrating_red_hat_developer_hub_with_github/index)

#### GitLab Group Import

Enable the GitLab catalog provider to import users from GitLab groups:

**Configuration in `app-config.yaml`:**

```yaml
catalog:
  providers:
    gitlab:
      yourProviderId:
        host: gitlab.com
        group: 'your-gitlab-group'
        schedule:
          frequency:
            minutes: 30
          timeout:
            minutes: 3
```

**Required Configuration:**
1. GitLab OAuth app configured in `auth.providers.gitlab`
2. GitLab integration configured in `integrations.gitlab`
3. Access token with `read_api` scope for the GitLab integration

See: [Guide to configuring multiple authentication providers in Developer Hub](https://developers.redhat.com/articles/2026/02/11/guide-configuring-multiple-authentication-providers-developer-hub)

#### Bitbucket Workspace Import

Bitbucket catalog provider support varies by version. Consult the [RHDH documentation](https://docs.redhat.com/en/documentation/red_hat_developer_hub/1.8/html-single/authentication_in_red_hat_developer_hub/index) for your version.

### Option 2: Manual User Definition (Development Only)

For local development and testing, you can manually define users in a YAML file:

**Configuration in `app-config.yaml`:**

```yaml
catalog:
  locations:
    - type: file
      target: ../../examples/org.yaml
      rules:
        - allow: [User, Group]
```

**Example `examples/org.yaml`:**

```yaml
apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: jdoe
spec:
  profile:
    displayName: Jane Doe
    email: jane.doe@example.com
  memberOf:
    - developers
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: developers
spec:
  type: team
  children: []
```

**Important:** Manual user definitions are **not recommended for production**. Use catalog providers to automatically sync users from your identity provider.

### Option 3: Multiple Identity Providers (Advanced)

Starting with RHDH 1.9.0, you can integrate multiple identity providers and catalog providers. This allows users from different sources (GitHub, GitLab, Keycloak, etc.) to coexist.

**Security Consideration:** When using multiple catalog providers, manage entities with conflicting entityRefs carefully. Always ensure the primary provider is the most trusted and authoritative source.

See: [Backstage authentication and catalog providers: A practical guide](https://developers.redhat.com/articles/2025/01/07/backstage-authentication-and-catalog-providers-practical-guide)

## Adding Users

To grant a user access to X2Ansible:

1. **Ensure the user has an account** with the configured OAuth provider (GitHub, GitLab, or Bitbucket)
2. **Import users to the catalog**:
   - **Production**: Configure catalog provider plugin to auto-import from your Git organization
   - **Development**: Add user entity to `examples/org.yaml` (not recommended for production)
3. **Assign permissions** via RBAC policies (see [Authorization]({% link latest/platform/authorization.md %}))

## Environment Variables

Set the following environment variables before starting the UI:

```bash
# GitHub OAuth
export AUTH_GITHUB_CLIENT_ID=your_github_client_id
export AUTH_GITHUB_CLIENT_SECRET=your_github_client_secret

# GitLab OAuth
export AUTH_GITLAB_CLIENT_ID=your_gitlab_client_id
export AUTH_GITLAB_CLIENT_SECRET=your_gitlab_client_secret

# Bitbucket OAuth
export AUTH_BITBUCKET_CLIENT_ID=your_bitbucket_key
export AUTH_BITBUCKET_CLIENT_SECRET=your_bitbucket_secret
```

## Authentication Flow

```mermaid
sequenceDiagram
    participant User
    participant UI as Backstage UI
    participant Backend as X2A Backend
    participant OAuth as OAuth Provider

    User->>UI: Click "Sign In"
    UI->>OAuth: Redirect to OAuth provider
    OAuth->>User: Request authorization
    User->>OAuth: Approve
    OAuth->>UI: Redirect with auth code
    UI->>Backend: Exchange code for token
    Backend->>OAuth: Validate token
    OAuth-->>Backend: User info + access token
    Backend-->>UI: Session cookie
    UI-->>User: Signed in

    Note over UI,Backend: Access token stored for Git operations
```

## Troubleshooting

### "User not found" after sign-in

**Cause**: User entity does not exist in the catalog.

**Solution**:
- **Production**: Ensure the catalog provider is configured and running. Check that the user is a member of the configured organization/group.
- **Development**: Add the user entity to `examples/org.yaml` and restart the backend.

### "Missing session cookie" on refresh

**Cause**: Popup and main window have different cookie contexts.

**Solution**: Set `enableExperimentalRedirectFlow: true` in `app-config.yaml` to use redirect flow instead of popup.

### OAuth callback errors

**Cause**: Callback URL mismatch between OAuth app configuration and actual deployment URL.

**Solution**: Verify the callback URL matches exactly (including protocol and port). Development callback URLs typically use `http://localhost:7007`, while production uses your public domain with HTTPS.

## Security Considerations

- **OAuth tokens** are stored securely and used for Git operations (clone, push)
- **Credentials** are passed to Kubernetes jobs as secrets and deleted after job completion
- **Session cookies** expire based on Backstage's default session management
- **Production deployments** should use HTTPS and secure session secrets
