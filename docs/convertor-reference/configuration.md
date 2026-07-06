---
layout: default
title: Configuration
parent: X2A Convertor Reference
nav_order: 2
---

# Configuration
{: .no_toc }

## Table of contents
{: .no_toc .text-delta }

* TOC
{:toc}

---

Configure X2A Convertor with environment variables or a `.env` file in the project root.

```bash
# .env
LLM_MODEL=claude-3-5-sonnet-20241022
AWS_BEARER_TOKEN_BEDROCK=your-token
LOG_LEVEL=INFO
```

## LLM Providers

### AWS Bedrock (Recommended)

```bash
LLM_MODEL=claude-3-5-sonnet-20241022
AWS_BEARER_TOKEN_BEDROCK=your-token
AWS_REGION=eu-west-2
```

Get token: AWS Console, Bedrock, Model Access

### OpenAI

```bash
LLM_MODEL=openai:gpt-4o
OPENAI_API_KEY=sk-your-key
```

Get key: <https://platform.openai.com/api-keys>

### Google Vertex AI

```bash
LLM_MODEL=google_vertexai:gemini-2.0-flash-exp
GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json
```

### Local (Ollama)

```bash
LLM_MODEL=openai:llama3:8b
OPENAI_API_BASE=http://localhost:11434/v1
OPENAI_API_KEY=not-needed
```

Install: `curl -fsSL https://ollama.com/install.sh | sh && ollama pull llama3:8b`

## Environment Variable Reference

### LLM Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `LLM_MODEL` | string | `openai/gpt-oss-120b-maas` | Language model to use |
| `MAX_TOKENS` | integer | `8192` | Maximum tokens for LLM responses |
| `TEMPERATURE` | float | `0.1` | Model temperature (creativity) |
| `REASONING_EFFORT` | string | - | Claude reasoning effort level |
| `RATE_LIMIT_REQUESTS` | integer | - | Rate limit requests per second |
| `LLM_MAX_RETRIES` | integer | `6` | Maximum retry attempts on throttling (429) and server errors |
| `LLM_READ_TIMEOUT` | integer | `900` | Read timeout in seconds for LLM API responses |
| `LLM_CONNECT_TIMEOUT` | integer | `60` | Connection timeout in seconds for LLM API connections |

### OpenAI Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `OPENAI_API_BASE` | string | - | OpenAI/compatible API endpoint |
| `OPENAI_API_KEY` | secret | `not-needed` | API key for OpenAI provider |

### AWS Bedrock Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `AWS_BEARER_TOKEN_BEDROCK` | secret | - | AWS Bedrock bearer token |
| `AWS_ACCESS_KEY_ID` | secret | - | AWS access key ID |
| `AWS_SECRET_ACCESS_KEY` | secret | - | AWS secret access key |
| `AWS_SESSION_TOKEN` | secret | - | AWS session token (temporary credentials) |
| `AWS_REGION` | string | `eu-west-2` | AWS region for Bedrock |

### Ansible Automation Platform Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `AAP_CONTROLLER_URL` | string | - | AAP Controller base URL |
| `AAP_ORG_NAME` | string | - | Organization name |
| `AAP_API_PREFIX` | string | `/api/controller/v2` | API path prefix |
| `AAP_OAUTH_TOKEN` | secret | - | OAuth token for auth |
| `AAP_USERNAME` | string | - | Username for basic auth |
| `AAP_PASSWORD` | secret | - | Password for basic auth |
| `AAP_CA_BUNDLE` | string | - | Path to CA certificate |
| `AAP_VERIFY_SSL` | boolean | `true` | SSL verification flag |
| `AAP_TIMEOUT_S` | float | `30.0` | Request timeout in seconds |
| `AAP_PROJECT_NAME` | string | - | Project name in AAP |
| `AAP_SCM_CREDENTIAL_ID` | integer | - | Credential ID for private repos |
| `AAP_GALAXY_REPOSITORY` | string | `published` | Galaxy repository to search (published, staging, community) |
| `AAP_EE_IMAGE` | string | `quay.io/x2ansible/ee-x2a:latest` | Execution Environment container image for AAP |
| `AAP_INVENTORY_NAME` | string | `Molecule Local` | AAP inventory name for molecule tests (created if missing) |

### Processing Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `RECURSION_LIMIT` | integer | `500` | Maximum recursion limit for LLM calls |
| `MAX_WRITE_ATTEMPTS` | integer | `10` | Maximum number of attempts to write all files from checklist |
| `MAX_VALIDATION_ATTEMPTS` | integer | `5` | Maximum number of attempts to fix validation errors |
| `X2A_ERROR_FILE` | string | - | File path to write error details on failure |
| `RULES_MAX_CHARS` | integer | `50000` | Maximum total characters allowed for organizational rules content |

### Logging Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `DEBUG_ALL` | boolean | `false` | Enable debug logging for all libraries |
| `LOG_LEVEL` | enum | `INFO` | Log level for x2convertor namespace (DEBUG, INFO, WARNING, ERROR, CRITICAL) |
| `JSON_LINES` | path | - | Path to directory for dumping agent messages in JSON Lines format |

### Molecule Testing Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `MOLECULE_DOCKER_IMAGE` | string | `docker.io/geerlingguy/docker-fedora40-ansible:latest` | Docker image for Molecule tests |

## Migration Behavior

### MAX_TOKENS

LLM response token limit.

**Range**: 1024-32768, **Default**: 8192

```bash
MAX_TOKENS=4096   # Small recipes
MAX_TOKENS=16384  # Large complex recipes
```

Higher values can handle larger files but cost more. Lower values are faster and cheaper but may truncate output.

### TEMPERATURE

LLM randomness/creativity.

**Range**: 0.0-1.0, **Default**: 0.1

```bash
TEMPERATURE=0.1  # Deterministic (recommended for migrations)
```

Keep at 0.1 for consistent, reproducible migrations.

### REASONING_EFFORT

Enable reasoning models with extended thinking.

**Values**: `low`, `medium`, `high`, or empty for standard mode.

```bash
LLM_MODEL=openai:o1-preview
REASONING_EFFORT=high
```

Use for complex conditional logic, intricate dependency resolution, or custom resource translations. Higher latency (30s-2min) and increased cost (10x), but better accuracy for complex scenarios.

### RECURSION_LIMIT

Maximum LangGraph state transitions.

**Range**: 50-200, **Default**: 100

Increase for large cookbooks (50+ files), deep dependency trees, or complex analysis workflows.

## Complete Configuration Examples

### Production (AWS Bedrock)

```bash
# .env
LLM_MODEL=claude-3-5-sonnet-20241022
AWS_BEARER_TOKEN_BEDROCK=ABSKQmVkcm9j...
AWS_REGION=eu-west-2
LOG_LEVEL=INFO
DEBUG_ALL=false
MAX_EXPORT_ATTEMPTS=5
RECURSION_LIMIT=100
MAX_TOKENS=8192
TEMPERATURE=0.1

# AAP Integration (optional)
AAP_CONTROLLER_URL=https://aap.example.com
AAP_ORG_NAME=my-org
AAP_OAUTH_TOKEN=your-oauth-token
AAP_GALAXY_REPOSITORY=published
```

### Development (OpenAI)

```bash
# .env
LLM_MODEL=openai:gpt-4o
OPENAI_API_KEY=sk-...
LOG_LEVEL=DEBUG
DEBUG_ALL=false
LANGCHAIN_DEBUG=true
LANGCHAIN_TRACING_V2=true
LANGCHAIN_API_KEY=ls_...
LANGCHAIN_PROJECT=x2a-dev
MAX_EXPORT_ATTEMPTS=3
MAX_TOKENS=8192
TEMPERATURE=0.1
```

### Air-Gapped (Local Ollama)

```bash
# .env
LLM_MODEL=openai:llama3:70b
OPENAI_API_BASE=http://localhost:11434/v1
OPENAI_API_KEY=not-needed
LOG_LEVEL=INFO
DEBUG_ALL=false
MAX_EXPORT_ATTEMPTS=7
RECURSION_LIMIT=150
MAX_TOKENS=16384
TEMPERATURE=0.1
```

## Security Best Practices

### Never Commit .env Files

```bash
echo ".env" >> .gitignore
```

### Use Secrets Management

**AWS Secrets Manager**:
```bash
export AWS_BEARER_TOKEN_BEDROCK=$(aws secretsmanager get-secret-value \
  --secret-id x2a/bedrock-token \
  --query SecretString \
  --output text)
```

**Kubernetes Secrets**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: x2a-config
type: Opaque
data:
  llm-model: Y2xhdWRlLTMtNS1zb25uZXQ=  # base64
  aws-token: QUJTSy4uLg==
```

### Restrict File Permissions

```bash
chmod 600 .env
```

### Use Environment-Specific Configs

```bash
# Load appropriate file
docker run --env-file .env.production x2a-convertor ...
```
