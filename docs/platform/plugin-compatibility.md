---
layout: default
title: Plugin Compatibility
parent: X2Ansible Platform
nav_order: 8
---

# Plugin Compatibility

The table below lists the plugin versions required to run the X2Ansible platform, along with the Backstage version each plugin is compatible with.

| Plugin | Version | Backstage Version | Container Image |
|--------|---------|--------------------|------------------|
{%- for plugin in site.data['rhdh-plugins-latest'].latest %}
| `{{ plugin[0] }}` | {{ plugin[1].version }} | {{ plugin[1].backstage_version }} | `{{ plugin[1].container_image }}` |
{%- endfor %}
