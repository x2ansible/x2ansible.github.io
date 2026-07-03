---
layout: default
title: Telemetry
parent: Advanced Features
nav_order: 3
---

# Telemetry

X2Ansible tracks execution metrics at every phase to provide visibility into migration performance and costs.

## What Gets Tracked

Each migration phase records telemetry data to `.x2a-telemetry.json` in the working directory. The platform collects this data from completed jobs and stores it alongside project artifacts.

### Phase-Level Metrics

- Phase name (init, analyze, migrate, publish)
- Start and end timestamps
- Total duration in seconds
- Aggregated tool call counts across all agents

### Agent-Level Metrics

Each AI agent within a phase records:

- Agent name and execution timestamps
- Duration in seconds
- Tool calls by name (e.g., `read_file`: 10, `ansible_lint`: 5)
- Custom metrics specific to the agent's task (e.g., `files_created`, `collections_found`, `attempts`)

## Example Output

```json
{
  "phase": "migrate",
  "started_at": "2026-01-26T09:35:26.192699",
  "ended_at": "2026-01-26T09:40:13.643805",
  "duration_seconds": 287.45,
  "agents": {
    "AAPDiscoveryAgent": {
      "duration_seconds": 10.02,
      "metrics": {"collections_found": 0},
      "tool_calls": {"aap_list_collections": 1, "aap_search_collections": 1}
    },
    "WriteAgent": {
      "duration_seconds": 223.83,
      "metrics": {"attempts": 10, "files_created": 22, "files_total": 23},
      "tool_calls": {"list_checklist_tasks": 15, "read_file": 10, "ansible_lint": 10}
    }
  },
  "total_tool_calls": {
    "aap_list_collections": 1,
    "read_file": 10,
    "ansible_lint": 10
  }
}
```

## Cost Visibility

Token usage (input and output) is tracked per agent. Combined with your LLM provider's pricing, this data lets you calculate the cost of each migration phase and estimate costs for remaining modules.

Typical migration costs depend on module complexity and the LLM model used. The telemetry data provides the inputs needed for accurate budgeting and chargeback reporting.

## Reporting

When running inside the platform, the convertor reports artifacts and telemetry to the backend through a callback endpoint. This data is stored with the project and accessible through the API.

The `report` CLI command can also push artifacts to the platform API when running the convertor standalone:

```bash
uv run app.py report \
  --source-dir ./chef-repo \
  --callback-url https://platform.example.com/api/x2a/projects/{id}/collectArtifacts
```

Callbacks are signed with HMAC-SHA256 for verification. The platform validates signatures and rejects reports older than 3 hours to prevent replay attacks.
