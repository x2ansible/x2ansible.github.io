---
layout: default
title: Publish
parent: Phases
nav_order: 4
---

# Publish Phase

Packages the migrated role into a deployable Ansible project and optionally syncs it to Ansible Automation Platform.

Publishing is split into two steps:

1. **publish-project**: Creates the local Ansible project structure
2. **publish-aap**: Syncs a Git repository to AAP Controller

## What Happens

### publish-project

On the first module, creates a full project skeleton:

```
<project-id>/ansible-project/
├── README.md
├── ansible.cfg
├── collections/requirements.yml
├── inventory/hosts.yml
├── roles/<role_name>/
├── run_<role_name>.yml
└── molecule_<role_name>.yml
```

On subsequent modules, appends the role directory and playbook. The README is regenerated to list all roles.

Role names are sanitized (hyphens to underscores, lowercased).

### publish-aap

Creates or updates an AAP Project pointing to the target Git repository and triggers a project sync.

Required configuration:
- `AAP_CONTROLLER_URL`
- `AAP_ORG_NAME`
- `AAP_OAUTH_TOKEN` or `AAP_USERNAME` + `AAP_PASSWORD`

Optional:
- `AAP_PROJECT_NAME` (inferred from repository if not set)
- `AAP_SCM_CREDENTIAL_ID` (for private Git repositories)
- `AAP_CA_BUNDLE` (for self-signed certificates)

## CLI Usage

```bash
# Create project structure (run once per module)
uv run app.py publish-project my-project nginx_multisite

# With custom collections and inventory (first module only)
uv run app.py publish-project my-project nginx_multisite \
  --collections-file ./collections.yml \
  --inventory-file ./inventory.yml

# Sync to AAP (after pushing to Git)
uv run app.py publish-aap \
  --target-repo https://github.com/org/my-project.git \
  --target-branch main \
  --project-id my-project
```

## Platform Usage

In the web interface, the Publish phase handles both steps: it creates the project structure, pushes to the target repository, and syncs to AAP if credentials are configured.

## Review Checklist

- Project structure follows Ansible conventions
- Playbook references the correct role
- `collections/requirements.yml` lists required collections
- `inventory/hosts.yml` contains intended hosts
- AAP Project syncs successfully (if using AAP)

## Key Properties

- **No LLM calls**: The publish phase is deterministic with no AI involvement
- **Incremental**: Add modules one at a time; the skeleton is created once
- **Idempotent**: Safe to re-run if the project structure needs regeneration
