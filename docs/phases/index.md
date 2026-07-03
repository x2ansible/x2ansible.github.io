---
layout: default
title: Phases
nav_order: 3
has_children: true
---

# Migration Phases

Detailed documentation for each phase of the X2Ansible migration workflow.

Each phase produces artifacts that should be reviewed before proceeding. In the platform UI, phases are triggered per module with a button click. With the CLI, each phase is a separate command.

### [Init]({% link phases/init.md %})
Scan the repository and produce a strategic migration plan.

### [Analyze]({% link phases/analyze.md %})
Deep analysis of a single module to produce a migration specification.

### [Migrate]({% link phases/migrate.md %})
Generate Ansible code from the migration specification.

### [Publish]({% link phases/publish.md %})
Package the Ansible role into a project and optionally sync to AAP.
