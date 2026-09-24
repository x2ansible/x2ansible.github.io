---
layout: default
title: Organizational Rules
parent: Advanced Features
nav_order: 1
---

# Organizational Rules

X2Ansible supports two types of rules that guide the migration process: generated rules that shape AI behavior during migration, and compliance rules that enforce organizational policies in the platform.

## Generated Rules

During the Init phase, the engine analyzes your source repository and generates two rule files:

- **INPUT-AGENTS.md**: Guidance for analysis agents. Contains technology-specific conventions extracted from your codebase, such as naming patterns, directory structures, and dependency handling approaches.
- **EXPORT-AGENTS.md**: Guidance for Ansible generation agents. Contains organizational standards for the generated output, such as preferred module usage, variable naming conventions, and role structure expectations.

These rules are injected into the AI agent conversations automatically. They help the migration engine produce output that matches your organization's existing Ansible practices rather than generic defaults.

### How Rules Are Applied

The rules middleware reads the generated rule files and injects their content as context into each agent's conversation. This happens transparently during the Analyze and Migrate phases. The maximum allowed size for rules content is 50,000 characters (configurable via `RULES_MAX_CHARS`).

### Customizing Generated Rules

After the Init phase generates the rule files, you can edit them manually before running Analyze or Migrate. Common customizations include:

- Adding preferred Ansible collections to use
- Specifying variable naming conventions
- Defining role structure requirements
- Setting restrictions on specific modules or patterns

## Platform Compliance Rules

In the web interface, administrators can create compliance rules through the rules management API. These rules represent organizational policies that teams must acknowledge when creating migration projects.

When a user creates a project (either through the UI or via CSV bulk import), they must accept all required rules. Accepted rules are stored with the project record for audit purposes.

### Managing Rules

Rules are managed through the REST API:

| Operation | Endpoint | Permission |
|-----------|----------|------------|
| List rules | `GET /api/x2a/rules` | Any authenticated user |
| Create rule | `POST /api/x2a/rules` | Admin write |
| Update rule | `PUT /api/x2a/rules/{id}` | Admin write |
| Delete rule | `DELETE /api/x2a/rules/{id}` | Admin write |

Each rule has a title, description, and a `required` flag. Required rules must be accepted before a project can proceed.
