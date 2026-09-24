---
layout: default
title: Deploying Nightly Plugins
parent: Developing
nav_order: 2
---

# Deploying Nightly Plugins

X2Ansible publishes nightly builds of its dynamic plugins to `quay.io/x2ansible` using the `nightly` tag. This is useful when you need to test unreleased fixes or features before they land in a tagged release.

## Nightly package references

To run nightly plugins, update the `dynamic-plugins` ConfigMap section of `deploy/app.yaml` so each X2A plugin `package` reference points at the `nightly` tag instead of a pinned version.


Rather than typing the `package` lines by hand, you can derive the full list of X2A plugin names directly from [`rhdh-plugins-latest.json`]({% link latest/platform/plugin-compatibility.md %}), the same data file that drives the [Plugin Compatibility]({% link latest/platform/plugin-compatibility.md %}) table. The plugin keys in that file always match the current set of X2A plugins that need to be shipped, so it's a reliable source for scripting the nightly `package` block.

```bash
URL="https://raw.githubusercontent.com/x2ansible/x2ansible.github.io/refs/heads/main/docs/_data/rhdh-plugins-latest.json"

curl -s "$URL" | jq -r '
  .latest | keys[] |
  "      - package: \"oci://quay.io/x2ansible/\(.):nightly!\(.)\""
'

```

Re-apply `deploy/app.yaml` and the RHDH operator will update all deployments.
