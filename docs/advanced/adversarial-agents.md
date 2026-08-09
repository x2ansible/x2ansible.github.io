---
layout: default
title: Adversarial Agents
parent: Advanced Features
nav_order: 4
---

# Adversarial Agents

Adversarial agents are read-only AI reviewers that inspect x2a migration artifacts - analysis plans and generated Ansible - before the output reaches production. They act as an automated peer review layer, catching security gaps, functional mistakes, and correctness problems that the primary migration agents may have missed.

Agents are defined in the web platform. Each agent has a name, a prompt describing what to look for, the phases it applies to, and the severity of its findings.

---

## How adversarial agents work

When you trigger an adversarial review from the module page, x2a:

1. Passes the relevant artifacts from the completed phase to the x2a-convertor `adversarial-run` command.
2. Runs each configured agent sequentially using read-only tools - agents cannot modify any files.
3. Produces a markdown report and a structured JSON summary in the module's output directory.
4. Surfaces the report and job details in the module page alongside the regular phase results.

**Supported phases:** adversarial reviews can run against `analyze` outputs (the analysis plan) or `migrate` outputs (the generated Ansible). The `init` and `publish` phases are not reviewable.

**Severity:** agents marked *critical* raise `CRITICAL` severity findings; all others raise `WARNING` severity findings. Critical findings signal blocking or high-priority issues.

---

## Managing agents

Adversarial agents are managed through the **Manage Adversarial Agents** link in the dashboard header.

| Operation | Description |
|-----------|-------------|
| Create | Define a name, a prompt describing what to review, the phases the agent applies to, and whether findings are critical |
| Edit | Update any field on an existing agent |
| Delete | Remove an agent; existing projects that selected the agent retain their snapshot |

No default agents are provided. Your organization decides what to review and at what severity.

Agents can also be managed directly through the REST API:

### REST API

| Operation | Endpoint | Permission |
|-----------|----------|------------|
| List agents | `GET /api/v1/adversarial-agents` | Any authenticated user |
| Create agent | `POST /api/v1/adversarial-agents` | Admin write |
| Get agent | `GET /api/v1/adversarial-agents/:id` | Any authenticated user |
| Update agent | `PUT /api/v1/adversarial-agents/:id` | Admin write |
| Delete agent | `DELETE /api/v1/adversarial-agents/:id` | Admin write |

---

## Selecting agents for a project

When creating a project with the scaffolder template, the **Adversarial Agents** field lets you pick which agents will be associated with the project. The selection is stored as a snapshot with the project record, so later edits to the agent definitions do not affect existing projects.

Only agents that are applicable to `analyze` or `migrate` appear in the picker.

---

## Running an adversarial review

Once an `analyze` or `migrate` phase has completed successfully, a **Run Adversarial Review** button appears on that tab in the module page. Click it to trigger the review for that phase.

The review runs as a standard x2a job - the same infrastructure, status polling, and artifact collection used by regular phases. You can watch its progress in the module page.

**Conflict behavior:** if an adversarial job is already running for the same module and phase, the request returns a `409 Conflict` and the existing job continues uninterrupted.

### Adversarial run endpoint

```
POST /api/v1/projects/:projectId/adversarial-run
```

Request body:

```json
{
  "phase": "analyze",
  "moduleId": "<uuid>",
  "targetRepoAuth": { "token": "<token>" }
}
```

Response (`202 Accepted`):

```json
{ "jobId": "<uuid>", "k8sJobName": "job-x2a-adversarial-analyze-abc123" }
```

| Status | Meaning |
|--------|---------|
| `202` | Job created and queued |
| `400` | No adversarial agents configured for this project, or invalid phase |
| `404` | Module not found |
| `409` | Adversarial job already running for this module and phase |

---

## Viewing results

After a review job completes, the module page shows a full **Adversarial Job Details** panel for the relevant phase, including:

- Job status and error details if it failed
- Adversarial report artifact link (the markdown findings report)
- Start time, duration, attempt count, and total elapsed time
- Kubernetes job name and internal job ID
- Streaming log viewer with a download option
- Telemetry table for cost and token usage

The panel is invisible until the first adversarial run completes for that phase.

---

## x2a-convertor CLI

The adversarial review is implemented as a standalone command in the convertor:

```bash
uv run app.py adversarial-run \
  --phase <analyze|migrate> \
  --source-dir <path-to-review> \
  --config <path-to-agents.json> \
  [--report-path <path-to-append-markdown>]
```

The command loads agent definitions from `--config`, filters by phase, runs agents sequentially with read-only tools, and writes:

- A markdown report (appended to `--report-path` if provided)
- `agent-adversarial-report.json` in the working directory

When deployed on Kubernetes, the agents ConfigMap is mounted at `/config/adversarial-agents/agents.json` and the job script passes this path as `--config`.
