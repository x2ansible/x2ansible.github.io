---
layout: default
title: The Migration Engine
parent: Concepts
nav_order: 1
---

# The Migration Engine

The x2a-convertor is the component that performs infrastructure code analysis and Ansible generation. Within the platform, it runs as a container inside Kubernetes jobs. It can also run standalone as a CLI tool.

## How It Works

The engine uses a multi-agent architecture built on LangGraph. Each migration phase runs a different set of agents, and each agent has access to specialized tools for parsing, analyzing, and generating code.

```mermaid
flowchart LR
    subgraph sources[Source Technologies]
        chef[Chef]
        powershell[PowerShell]
        ansible_in[Ansible]
        puppet[Puppet]
    end
    
    router[Technology Router]
    
    subgraph agents[Analysis Agents]
        chef_agent[Chef Agent]
        ps_agent[PowerShell Agent]
        ansible_agent[Ansible Agent]
        puppet_agent[Puppet Agent]
    end
    
    subgraph engine[Migration Engine]
        migration[Code Generator]
        validation[Validation]
    end
    
    ansible_out[Ansible Role]
    
    chef --> router
    powershell --> router
    ansible_in --> router
    puppet --> router
    
    router --> chef_agent
    router --> ps_agent
    router --> ansible_agent
    router --> puppet_agent
    
    chef_agent --> migration
    ps_agent --> migration
    ansible_agent --> migration
    puppet_agent --> migration
    
    migration --> validation
    validation --> ansible_out
    
    style sources fill:#f5f5f5
    style chef fill:#ffffff
    style powershell fill:#ffffff
    style ansible_in fill:#ffffff
    style puppet fill:#ffffff
    style router fill:#fff3e0
    style agents fill:#fff3e0,stroke:#ff9800
    style chef_agent fill:#fff3e0
    style ps_agent fill:#fff3e0
    style ansible_agent fill:#fff3e0
    style puppet_agent fill:#fff3e0
    style engine fill:#fff3e0,stroke:#ff9800
    style migration fill:#fff3e0
    style validation fill:#fff3e0
    style ansible_out fill:#e8f5e9
```

The engine detects the source technology automatically and routes to the appropriate analysis agent. Each agent understands the conventions of its source language: the Chef agent uses Tree-sitter for Ruby parsing and resolves Supermarket dependencies, the PowerShell agent handles DSC configurations and script modules, and the Ansible agent modernizes legacy roles across 21 categories.

## Supported Technologies

| Source | Status | What Gets Analyzed |
|--------|--------|--------------------|
| Chef | Full support | Cookbooks, recipes, templates, attributes, Supermarket dependencies |
| PowerShell | Full support | Scripts, modules, DSC configurations |
| Ansible | Full support | Legacy roles (modernization to current best practices) |
| Puppet | Full support | Manifests, modules, Hiera data |
| Salt | Basic support | State files |

## LLM Providers

The engine supports multiple LLM backends. The choice of provider does not affect the migration workflow, only the underlying model used for analysis and generation.

| Provider | Configuration | Use Case |
|----------|---------------|----------|
| AWS Bedrock | `AWS_BEARER_TOKEN_BEDROCK` | Enterprise environments with AWS infrastructure |
| OpenAI | `OPENAI_API_KEY` | Development, testing, OpenAI-compatible endpoints |
| Google Vertex AI | `GOOGLE_APPLICATION_CREDENTIALS` | GCP environments |
| Local models (Ollama, vLLM) | `OPENAI_API_BASE` | Air-gapped networks, on-premise deployments |

## Validation

Generated Ansible code goes through automated validation using ansible-lint. The engine retries up to 5 times, using the LLM to fix lint errors between attempts. This loop runs before any human review, so the output that reaches reviewers has already passed basic quality checks.

## Platform Integration

When running inside the platform, the engine receives its configuration through Kubernetes secrets (LLM credentials, Git tokens, AAP credentials). It reports results back to the platform through a webhook callback with HMAC signature verification. The platform stores artifacts, telemetry, and migration plans in its database and updates the project status in the UI.

When running standalone, the engine reads configuration from environment variables or a `.env` file and writes output directly to the filesystem.
