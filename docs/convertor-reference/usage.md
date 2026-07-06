---
layout: default
title: Usage Examples
parent: X2A Convertor Reference
nav_order: 3
---

# Usage Examples
{: .no_toc }

## Table of contents
{: .no_toc .text-delta }

* TOC
{:toc}

---

Both native CLI and Docker/Podman examples for each migration phase.

## Prerequisites

Clone the example repository:

```bash
git clone https://github.com/x2ansible/chef-examples.git
cd chef-examples
```

Set the required environment variables (this guide uses AWS Bedrock):

```bash
export LLM_MODEL=anthropic.claude-3-7-sonnet-20250219-v1:0
export AWS_REGION=your-aws-region
export AWS_BEARER_TOKEN_BEDROCK=your-bearer-token
```

For AAP collection discovery during migration (optional):

```bash
export AAP_CONTROLLER_URL=your-aap-url
export AAP_ORG_NAME=your-org-name
export AAP_OAUTH_TOKEN=your-oauth-token
export AAP_GALAXY_REPOSITORY=published  # published, staging, or community
```

## Initialization

Creates the `migration-plan.md` reference file.

**Native CLI**:

```bash
uv run app.py init \
  --source-dir . \
  "Migrate to Ansible"
```

**Docker/Podman**:

```bash
podman run --rm -ti \
  -v $(pwd)/:/app/source:Z \
  -e LLM_MODEL=anthropic.claude-3-7-sonnet-20250219-v1:0 \
  -e AWS_REGION=$AWS_REGION \
  -e AWS_BEARER_TOKEN_BEDROCK=$AWS_BEARER_TOKEN_BEDROCK \
  quay.io/x2ansible/x2a-convertor:latest \
  init --source-dir /app/source "Migrate to Ansible"
```

## Analyze

Produces a module-level migration blueprint. For the nginx-multisite cookbook, this creates `migration-plan-nginx-multisite.md`.

**Native CLI**:

```bash
uv run app.py analyze \
  --source-dir . \
  "please make a detailed plan for nginx-multisite"
```

**Docker/Podman**:

```bash
podman run --rm -ti \
  -v $(pwd)/:/app/source:Z \
  -e LLM_MODEL=anthropic.claude-3-7-sonnet-20250219-v1:0 \
  -e AWS_REGION=$AWS_REGION \
  -e AWS_BEARER_TOKEN_BEDROCK=$AWS_BEARER_TOKEN_BEDROCK \
  quay.io/x2ansible/x2a-convertor:latest \
  analyze --source-dir /app/source/ "please make a detailed plan for nginx-multisite"
```

## Migrate

Generates Ansible code in `ansible/roles/nginx_multisite`. When AAP environment variables are set, it also searches your Private Automation Hub for reusable collections.

**Native CLI**:

```bash
uv run app.py migrate \
  --source-dir . \
  --source-technology Chef \
  --high-level-migration-plan migration-plan.md \
  --module-migration-plan migration-plan-nginx-multisite.md \
  "Convert the 'nginx-multisite' module"
```

**Docker/Podman**:

```bash
podman run --rm -ti \
  -v $(pwd)/:/app/source:Z \
  -e LLM_MODEL=anthropic.claude-3-7-sonnet-20250219-v1:0 \
  -e AWS_REGION=$AWS_REGION \
  -e AWS_BEARER_TOKEN_BEDROCK=$AWS_BEARER_TOKEN_BEDROCK \
  -e AAP_CONTROLLER_URL=$AAP_CONTROLLER_URL \
  -e AAP_ORG_NAME=$AAP_ORG_NAME \
  -e AAP_OAUTH_TOKEN=$AAP_OAUTH_TOKEN \
  -e AAP_GALAXY_REPOSITORY=$AAP_GALAXY_REPOSITORY \
  quay.io/x2ansible/x2a-convertor:latest \
  migrate --source-dir /app/source/ --source-technology Chef --high-level-migration-plan migration-plan.md --module-migration-plan migration-plan-nginx-multisite.md "Convert the 'nginx-multisite' module"
```

## Publish Project

Creates (or appends to) an Ansible project under `<project-id>/ansible-project/`. On the first module it creates the full skeleton (ansible.cfg, collections, inventory). On subsequent modules it adds the role and playbook.

**Native CLI**:

```bash
uv run app.py publish-project my-migration-project nginx_multisite
```

**Docker/Podman**:

```bash
podman run --rm -ti \
  -v $(pwd)/:/app/source:Z \
  quay.io/x2ansible/x2a-convertor:latest \
  publish-project my-migration-project nginx_multisite
```

Output structure:

- `<project-id>/ansible-project/ansible.cfg`
- `<project-id>/ansible-project/collections/requirements.yml`
- `<project-id>/ansible-project/inventory/hosts.yml`
- `<project-id>/ansible-project/roles/nginx_multisite/`
- `<project-id>/ansible-project/run_nginx_multisite.yml`

## Publish to AAP (Optional)

Creates or updates an AAP Project pointing to the given repository and branch, then triggers a project sync.

**Native CLI**:

```bash
uv run app.py publish-aap \
  --target-repo https://github.com/companyName/my-migration-project.git \
  --target-branch main \
  --project-id my-migration-project
```

**Docker/Podman**:

```bash
podman run --rm -ti \
  -v $(pwd)/:/app/source:Z \
  -e AAP_CONTROLLER_URL=$AAP_CONTROLLER_URL \
  -e AAP_ORG_NAME=$AAP_ORG_NAME \
  -e AAP_OAUTH_TOKEN=$AAP_OAUTH_TOKEN \
  quay.io/x2ansible/x2a-convertor:latest \
  publish-aap --target-repo https://github.com/companyName/my-migration-project.git --target-branch main --project-id my-migration-project
```

## Notes

Publishing is split into two separate commands:

- **`publish-project`** creates the local Ansible project structure. Run it once per migrated module.
- **`publish-aap`** syncs a git repository to AAP. Run it after pushing your project to a git repository.

To skip the AAP sync, omit the `publish-aap` step. The `publish-project` command is always local-only.
