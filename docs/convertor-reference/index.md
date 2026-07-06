---
layout: default
title: X2A Convertor Reference
nav_order: 5
has_children: true
---

# X2A Convertor Reference

The x2a-convertor is the migration engine that powers X2Ansible. It can run inside the platform as Kubernetes jobs, or standalone as a CLI tool.

This section covers standalone CLI usage.

## Installation

### Docker (Recommended)

```bash
git clone https://github.com/x2ansible/x2a-convertor.git
cd x2a-convertor
docker build -t x2a-convertor:latest .
docker run --rm x2a-convertor:latest --help
```

The container image includes Python 3.12, Chef Workstation CLI, and all dependencies.

### Local Installation

Requires Python 3.12+ and [uv](https://astral.sh/uv).

```bash
git clone https://github.com/x2ansible/x2a-convertor.git
cd x2a-convertor
uv sync
uv run app.py --help
```

For Chef cookbook analysis, install [Chef Workstation](https://docs.chef.io/workstation/install_workstation/) separately.

## Quick Start

Using the [chef-examples](https://github.com/x2ansible/chef-examples) repository:

```bash
git clone https://github.com/x2ansible/chef-examples.git
cd chef-examples

# Set LLM credentials
export LLM_MODEL=anthropic.claude-3-7-sonnet-20250219-v1:0
export AWS_REGION=your-region
export AWS_BEARER_TOKEN_BEDROCK=your-token

# Run the four phases
uv run app.py init --source-dir . "Migrate to Ansible"
uv run app.py analyze --source-dir . "Analyze nginx-multisite cookbook"
uv run app.py migrate \
  --source-dir . \
  --source-technology Chef \
  --high-level-migration-plan migration-plan.md \
  --module-migration-plan migration-plan-nginx-multisite.md \
  "Convert nginx-multisite"
uv run app.py publish-project my-project nginx_multisite
```

## Documentation

- [CLI Reference]({% link convertor-reference/cli-reference.md %}): Complete command documentation
- [Configuration]({% link convertor-reference/configuration.md %}): Environment variables and LLM provider setup
- [Usage Examples]({% link convertor-reference/usage.md %}): Detailed CLI and Docker usage examples

## Source Technologies

- [Chef]({% link convertor-reference/chef.md %}): Cookbook analysis and migration
- [PowerShell]({% link convertor-reference/powershell.md %}): Script and DSC configuration migration
- [Ansible]({% link convertor-reference/ansible.md %}): Legacy role modernization
- [Puppet]({% link convertor-reference/puppet.md %}): Manifest analysis and migration
