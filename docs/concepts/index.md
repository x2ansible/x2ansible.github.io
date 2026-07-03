---
layout: default
title: Concepts
nav_order: 2
has_children: true
---

# Concepts

X2Ansible is built from three main components that work together as a platform.

## The Platform

The web interface runs on Red Hat Developer Hub (or vanilla Backstage). It provides project management, user authentication, role-based access control, and a REST API. Teams create migration projects through the browser, connect their source and target Git repositories, and track progress across modules.

When a user triggers a migration phase, the backend creates a Kubernetes job. That job runs the x2a-convertor container, which performs the actual analysis and code generation using LLM providers. Results are reported back to the platform, stored in the database, and pushed to the target Git repository.

```mermaid
sequenceDiagram
    participant User
    participant UI as Web Interface
    participant Backend as Backend Plugin
    participant K8s as Kubernetes
    participant Engine as x2a-convertor
    participant LLM as LLM Provider
    participant Git as Git Repository

    rect rgb(255, 235, 238)
        Note over User,UI: Red Hat Developer Hub
        User->>UI: Trigger migration phase
        UI->>Backend: API request
    end
    
    rect rgb(227, 242, 253)
        Note over Backend,K8s: Platform Orchestration
        Backend->>K8s: Create job
        K8s->>Engine: Run migration
    end
    
    rect rgb(255, 243, 224)
        Note over Engine,LLM: Migration Engine
        Engine->>LLM: Analyze and generate code
        LLM-->>Engine: Results
    end
    
    rect rgb(243, 229, 245)
        Note over Engine,Git: External Integration
        Engine->>Git: Push converted Ansible code
        Engine->>Backend: Report artifacts and telemetry
    end
    
    rect rgb(255, 235, 238)
        Note over Backend,User: User Feedback
        Backend-->>UI: Update status
        UI-->>User: Display results
    end
```

## Topics

### [The Migration Engine]({% link concepts/convertor.md %})
How x2a-convertor analyzes source code and generates Ansible output.

### [Migration Phases]({% link concepts/phases.md %})
The four-phase workflow: Init, Analyze, Migrate, and Publish.
