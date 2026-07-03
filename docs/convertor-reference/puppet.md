---
layout: default
title: Puppet
parent: X2A Convertor Reference
nav_order: 7
---

# Puppet

The Puppet agent analyzes Puppet manifests, modules, and Hiera data to produce migration specifications for conversion to Ansible.

## Supported Features

| Category | Puppet Feature | Analysis Output |
|----------|---------------|-----------------|
| Manifests | Class and defined type declarations | Resource mapping to Ansible modules |
| Modules | Module structure and dependencies | Role structure and collection requirements |
| Hiera | Hierarchical data lookups | Variable mapping to Ansible defaults and vars |
| Resources | Package, file, service, exec, and others | Task generation with equivalent Ansible modules |

## Workflow

The Puppet agent follows the same analysis workflow as other input agents:

1. Scan for `.pp` manifests and `metadata.json`
2. Parse module structure and resolve dependencies
3. Analyze resources and map to Ansible equivalents
4. Generate migration specification
5. Validate completeness
