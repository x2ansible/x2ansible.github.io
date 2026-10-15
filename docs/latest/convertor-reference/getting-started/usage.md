---
layout: default
title: Usage
parent: Getting Started
grand_parent: X2A Convertor Reference
nav_order: 1
---

# Usage

Run X2A Convertor natively for local development and quick migrations.

## Quick Reference

We're using this repository as default test project:

```
git clone https://github.com/x2ansible/chef-examples.git
cd chef-examples
```

## Requirements

This example uses the AWS Bedrock provider. You'll need to configure the following environment variables:

- **AWS_REGION**: The AWS region where the model will run
- **AWS_BEARER_TOKEN_BEDROCK**: The API key to connect to the LLM
- **LLM_MODEL**: The model to use (this guide uses `bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0`)

Export these variables in your shell before running commands:

```bash
# LLM provider — format: provider/model-name (see Requirements table above)
export LLM_MODEL=bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0

# AWS Bedrock credentials
export AWS_REGION=your-aws-region
export AWS_BEARER_TOKEN_BEDROCK=your-bearer-token

# Optional: AAP Collection Discovery during migrate and publish-aap sync
export AAP_CONTROLLER_URL=your-aap-url
export AAP_ORG_NAME=your-org-name
export AAP_OAUTH_TOKEN=your-oauth-token  # or use AAP_USERNAME and AAP_PASSWORD
export AAP_GALAXY_REPOSITORY=published  # published, staging, or community

# AAP integration extra configuration (optional)
export AAP_CA_BUNDLE=your-ca-bundle-path
export AAP_VERIFY_SSL=true
```

## Initialization

The first thing we need to do is create the migration-plan.md file which will be used as a reference file:

```bash
uv run app.py init \
  --source-dir . \
  "Migrate to Ansible"

```

This will create a **migration-plan.md** with a lot of details.

## Analyze:

```bash
uv run app.py analyze \
  --source-dir . \
  "please make a detailed plan for nginx-multisite"

```

This will make a blueprint of what the model understands about the migration of that cookbook. In this case, it will create a **migration-plan-nginx-multisite.md**

## Migrate

```bash
uv run app.py migrate \
  --source-dir . \
  --source-technology Chef \
  --high-level-migration-plan migration-plan.md \
  --module-migration-plan migration-plan-nginx-multisite.md \
  "Convert the 'nginx-multisite' module"

```

This generates a complete Ansible project under `ansible/` using ansible-creator, with roles in `ansible/collections/ansible_collections/x2a/project/roles/`. Publish this project directly; no separate assembly step is needed. When AAP env vars are set, migrate also searches Private Automation Hub for reusable collections.

## Publish to AAP (Optional)

```bash
uv run app.py publish-aap \
  --target-repo https://github.com/companyName/my-migration-project.git \
  --target-branch main \
  --project-id my-migration-project

```

Commit and push the complete generated `ansible/` project to your Git repository first, preserving its layout. This command creates or updates an AAP Project pointing to that repository and branch, then requests a project sync without waiting for completion. It does not copy local files, push Git commits, or configure Molecule, execution environments, inventories, or job templates.

## Notes

The migrate step already creates the Ansible project. Commit and push that project, then optionally run **`publish-aap`** to register it with AAP and request a sync. Check the sync job's final status in AAP.

`--project-id` identifies the migration for AAP naming; it is not a local path or a repository subdirectory selector. `AAP_PROJECT_NAME`, when set, overrides the AAP project name.

Molecule scenarios remain part of the generated project and are run separately by developers or CI, not by publishing.

To **skip the AAP sync**, simply omit the `publish-aap` step.
