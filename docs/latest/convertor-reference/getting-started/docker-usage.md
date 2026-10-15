---
layout: default
title: Docker Usage
parent: Getting Started
grand_parent: X2A Convertor Reference
nav_order: 2
---

# Docker Usage

Run X2A Convertor in containers for reproducible, enterprise-grade deployments.

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

## Initialization

The first thing we need to do is create the migration-plan.md file which will be used as a reference file:

```bash
podman run --rm -ti \
  -v $(pwd)/:/app/source:Z \
  -e LLM_MODEL=bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0 \
  -e AWS_REGION=$AWS_REGION \
  -e AWS_BEARER_TOKEN_BEDROCK=$AWS_BEARER_TOKEN_BEDROCK \
  quay.io/x2ansible/x2a-convertor:latest \
  init --source-dir /app/source "Migrate to Ansible"
```

This will create a **migration-plan.md** with a lot of details.

## Analyze:

```bash
podman run --rm -ti \
  -v $(pwd)/:/app/source:Z \
  -e LLM_MODEL=bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0 \
  -e AWS_REGION=$AWS_REGION \
  -e AWS_BEARER_TOKEN_BEDROCK=$AWS_BEARER_TOKEN_BEDROCK \
  quay.io/x2ansible/x2a-convertor:latest \
  analyze "please make a detailed plan for nginx-multisite"  --source-dir /app/source/
```

This will make a blueprint of what the model understands about the migration of that cookbook. In this case, it will create a **migration-plan-nginx-multisite.md**

## Migrate

```bash
podman run --rm -ti \
  -v $(pwd)/:/app/source:Z \
  -e LLM_MODEL=bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0 \
  -e AWS_REGION=$AWS_REGION \
  -e AWS_BEARER_TOKEN_BEDROCK=$AWS_BEARER_TOKEN_BEDROCK \
  -e AAP_CONTROLLER_URL=$AAP_CONTROLLER_URL \
  -e AAP_ORG_NAME=$AAP_ORG_NAME \
  -e AAP_OAUTH_TOKEN=$AAP_OAUTH_TOKEN \
  -e AAP_GALAXY_REPOSITORY=$AAP_GALAXY_REPOSITORY \
  quay.io/x2ansible/x2a-convertor:latest \
  migrate --source-dir /app/source/ --source-technology Chef --high-level-migration-plan migration-plan.md --module-migration-plan migration-plan-nginx-multisite.md "Convert the 'nginx-multisite' module"
```

This generates a complete Ansible project under `ansible/` using ansible-creator, with roles in `ansible/collections/ansible_collections/x2a/project/roles/`. Publish this project directly; no separate assembly step is needed. When AAP env vars are set, migrate also searches Private Automation Hub for reusable collections.

## Publish to AAP (Optional)

```bash
podman run --rm -ti \
  -v $(pwd)/:/app/source:Z \
  -e AAP_CONTROLLER_URL=$AAP_CONTROLLER_URL \
  -e AAP_ORG_NAME=$AAP_ORG_NAME \
  -e AAP_OAUTH_TOKEN=$AAP_OAUTH_TOKEN \
  quay.io/x2ansible/x2a-convertor:latest \
  publish-aap --target-repo https://github.com/companyName/my-migration-project.git --target-branch main --project-id my-migration-project
```

Commit and push the complete generated `ansible/` project to your Git repository first, preserving its layout. This command creates or updates an AAP Project pointing to that repository and branch, then requests a project sync without waiting for completion. It does not copy local files, push Git commits, or configure Molecule, execution environments, inventories, or job templates.
