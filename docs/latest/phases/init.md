---
layout: default
title: Init
parent: Phases
nav_order: 1
---

# Init Phase

Scans the entire source repository to produce a strategic migration plan.

## What Happens

1. The init agent scans the repository directory structure
2. Reads metadata files (metadata.rb, Berksfile, manifests, etc.)
3. Identifies all modules or cookbooks
4. Maps dependency relationships between them
5. Generates a migration plan with recommended order and complexity estimates

## Output

**File**: `migration-plan.md`

Contains:
- Repository structure overview
- List of all identified modules
- Dependency graph
- Recommended migration order
- Estimated complexity per module
- Metadata file for platform usage

**File**: `generated-project-metadata.json`

Structured metadata with detected source technology, module list, and dependency information. Used by subsequent phases and by the platform UI to display module status.

## CLI Usage

```bash
uv run app.py init --source-dir ./chef-repo "Migrate to Ansible"
```

Use `--refresh` to skip plan generation if a plan already exists and only regenerate metadata.

## Platform Usage

In the web interface, click "Init Project" on the project page. The platform creates a Kubernetes job that runs the init phase, clones the source repository, and pushes the migration plan to the target repository.

## Review Checklist

Before proceeding to Analyze:

- All expected modules are identified
- Dependency relationships are accurate
- Migration priority order aligns with your deployment architecture
- External dependencies are noted
- Complexity estimates are reasonable

## Re-running Init

The init phase is idempotent. Re-run it with refined requirements to adjust the plan:

```bash
uv run app.py init --source-dir ./chef-repo "Prioritize security cookbooks first"
```
