---
layout: default
title: Adversarial Agents
parent: Advanced Features
nav_order: 4
---

# Adversarial Agents

Adversarial agents are **read-only** AI reviewers that inspect x2a migration artifacts - analysis plans and generated Ansible - before the output reaches production. They act as an automated peer review layer, catching security gaps, functional mistakes, and correctness problems that the primary migration agents may have missed.

Adversarial agents are defined by a system administrator in the web platform. Each agent has a name, a prompt describing what to look for, the phases it applies to, and the severity of its findings.

---

## How adversarial agents work

When you trigger an adversarial review from the module page, the platform:

1. Runs each selected agent sequentially using read-only tools - agents cannot modify any files.
2. Produces a markdown findings report and a structured JSON summary - `adversarial-report-<phase>.md` and `adversarial-report-<phase>.json` (e.g. `adversarial-report-analyze.md`) - committed back to the target repository alongside the reviewed phase artifacts.
3. Surfaces the report and job details in the module page alongside the regular phase results.

**Supported phases:** adversarial reviews can run against `analyze` outputs (the analysis plan) or `migrate` outputs (the generated Ansible). The `init` and `publish` phases are not reviewable.

**Severity:** an agent's *critical* flag sets the default severity of its findings - critical agents emit `CRITICAL` findings, all others emit `WARNING`. Both severities appear in the report and in the finding counts shown in the UI; the distinction is a priority signal for the human reviewer and does not gate the workflow.

---

## Managing agents

Adversarial agents are managed through the **Manage Adversarial Agents** link in the dashboard header.

| Operation | Description |
|-----------|-------------|
| Create | Define a name, a prompt describing what to review, the phases the agent applies to, and whether findings are critical |
| Edit | Update any field on an existing agent |
| Delete | Remove an agent |

No default agents are provided. Your organization decides what to review and at what severity.

Adversarial agents can also be created and managed programmatically. See the [API Reference]({% link platform/api-reference.md %}) for the `adversarial-agents` endpoints.

---

## Example agent

The prompt is the heart of an adversarial agent - it is the instruction handed to the reviewer. Keep it specific: name the concrete problems the agent should hunt for and tell it how to report them.

The following agent reviews the generated Ansible during the `migrate` phase, looking for destructive operations that have no safety boundary:

| Field | Value |
|-------|-------|
| Name | `Destructive Operation Boundary` |
| Phases | `migrate` |
| Critical | Yes |
| Prompt | Scan generated Ansible roles for destructive operations: `rm -rf`, `state: absent` on broad patterns, unguarded shell commands with `rm`/`dd`/`mkfs`, firewall rule deletion, user account deletion. Verify each has explicit safeguards: `check_mode` support, confirmation variables, or scope limitations. Flag any destructive operation without a safety boundary. For each finding, report the affected file and task and include the evidence showing why it is unsafe. |

When it runs, it reads the generated role with read-only tools and writes its findings to the phase report. A representative entry:

````markdown
## Adversarial Review Findings

**Agent:** Destructive Operation Boundary

### [CRITICAL] roles/app/tasks/cleanup.yml

Unguarded destructive command with no check_mode support or scope limit

**Evidence:**
```
The task "Remove old release directories" runs
`command: rm -rf /opt/app/releases/{{ item }}` in a loop with no check_mode
support and no confirmation variable, so an empty or unexpected `item` value
could delete the entire releases directory.
```
````

---

## Good practice

- **One concern per agent.** A focused security agent and a separate idempotency agent produce clearer, actionable reports than a single agent asked to check everything.
- **Don't mark every agent critical.** Severity is only useful as a signal if it's selective - reserve *critical* for the checks a reviewer should look at first and leave routine or best-practice checks as `WARNING`.
- **Write prompts that ask for evidence.** Instruct the agent to name the file and task and to explain *why* something is a problem, so a reviewer can act on the finding without re-reading the whole role.

---

## Running an adversarial review

Once an `analyze` or `migrate` phase has completed successfully, an **Adversarial Review** accordion appears on that tab in the module page. Inside it, select one or more agents from the multi-select dropdown and click **Run Adversarial Review**. The button is disabled until at least one agent is selected.

The dropdown is filtered to agents applicable to the current phase. You can run the review multiple times with different agent selections; each run replaces the previous adversarial job for that phase.

The review runs as a standard x2a job - the same infrastructure, status polling, and artifact collection used by regular phases. You can watch its progress in the module page.

**Conflict behavior:** if an adversarial job is already running for the same module and phase, the request is rejected and the existing job continues uninterrupted.

---

## Viewing results

As soon as a phase completes successfully, the **Adversarial Review** accordion becomes visible on that tab - even before any adversarial run has been triggered. After a run completes, the accordion summary shows the finding counts (critical and warning). Expanding it shows:

- Job status and error details if it failed
- Adversarial report artifact link (the markdown findings report)
- Critical findings count and warning findings count
- Start time, duration, attempt count, and total elapsed time
- Kubernetes job name, internal job ID, and commit ID
- Streaming log viewer with a download option
