---
layout: default
title: Installation (VM)
parent: X2Ansible Platform
nav_order: 2
---

<link rel="stylesheet" href="{{ '/latest/platform/vm-assets/configurator.css' | relative_url }}">

# Install X2Ansible on a VM

X2Ansible helps teams move Chef, Puppet, and PowerShell automation to Ansible. Use this guide to evaluate its VM image in an isolated AWS environment, or to build a local development VM and try the application with test data. The steps walk you through prerequisites, application settings, and launch.

{: .info }
> **Evaluation image.** The AWS AMI is a development image with a self-signed localhost certificate, not a production appliance. Use an isolated environment and avoid sensitive data. For a cluster deployment, see [Installation on OpenShift]({% link latest/platform/installation.md %}).

## Step 1 — Prepare

Choose your environment. You do not need to build or import the AWS AMI.

{% tabs prepare %}
{% tab prepare AWS %}
### AWS evaluation checklist

- **Image supplied by X2Ansible:** public AMI `ami-089d5093ffb0de139` in **us-east-1**. In the EC2 console, verify its owner, release, architecture, and availability before launch. AMI IDs are Region-specific; no other Region is documented yet.
- **You supply:** an AWS account and approved console sign-in; an existing VPC and subnet, plus an approved way to reach the VM (for example, VPN). Ask your cloud team if you don't have these.
- **You supply:** a security group that permits HTTPS (443) only from your approved IP/VPN range. If SSH is needed, restrict port 22 to administrator IPs. **Do not use `0.0.0.0/0`.** A public AMI does not make a publicly accessible application safe.
- **You choose:** a compatible instance type based on the AMI architecture (at least 4 vCPUs and 16 GiB RAM is a development starting point), an encrypted disk of at least 60 GiB, an administration method, an owner, and a teardown date. EC2 and EBS incur charges.
- **Application settings:** choose your LLM, Git sign-in provider, and optional AAP connection in Step 2.
{% endtab %}
{% tab prepare Local %}
### Local development prerequisites

You need Linux, rootless Podman, Make, `bcvk`, libvirt, QEMU/KVM, virtiofsd, `ip`, `jq`, and access to `/dev/kvm`. Allow 4 CPUs, 16 GiB RAM, and a 60 GiB persistent disk.

Clone this repository and work in `vm/`. See the [VM README](https://github.com/x2ansible/x2ansible.github.io/tree/main/vm#readme) for prerequisites and current limitations.
{% endtab %}
{% endtabs %}

## Step 2 — Configure

Set your LLM, Git sign-in provider, and optional AAP connection in the form below. Select **Download user-data** to get the cloud-init configuration for Step 3.

<noscript>JavaScript is required for the builder. Alternatively, edit <code>vm/cloud-init/user-data</code> following the VM README, using dummy values only.</noscript>

{% include vm-configurator.html %}
<script src="{{ '/latest/platform/vm-assets/configurator.js' | relative_url }}" defer></script>

## Step 3 — Deploy

{% tabs deploy %}
{% tab deploy AWS %}
### Launch the AWS evaluation VM from the web console

{: .info }
1. Sign in to your AWS account and select **us-east-1**. Open [EC2 → Launch instances](https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#LaunchInstances:).
2. Under **Application and OS Images**, find `ami-089d5093ffb0de139`; verify its owner, release and architecture. Select a compatible instance type.
3. Under **Network settings**, choose your approved VPC/subnet and a security group limited to your approved IP/VPN source. Do not allow SSH or HTTPS from anywhere.
4. Choose your administration method. Under **Storage**, review encryption and capacity (60 GiB minimum for this development image).
5. Expand **Advanced details** and paste the contents of the Step 2 download into **User data**. Review estimated charges and launch.
6. Wait for EC2 status checks. If you have guest access, run `sudo /opt/x2a/status.sh` to check the application. EC2 **Running** status alone does not confirm it has started. The image's certificate is for `localhost`, not an AWS hostname.


{% endtab %}
{% tab deploy Local %}
### Build and launch a fresh development VM

Save the Step 2 download as `vm/cloud-init/user-data`. Keep `vm/cloud-init/meta-data`: NoCloud needs both. From `vm/`, run:

```bash
make build
make virt-serve  # separate terminal; dummy credentials only
```

In another terminal:

```bash
make run
make ssh
# Inside the guest, as root:
/opt/x2a/status.sh
```

Open [https://localhost:8443](https://localhost:8443). The development certificate is self-signed and valid for 30 days. Startup may return 502/503 until RHDH is ready. Keep the VM private: development authentication and broad permissions are enabled, and host port forwarding may bind all interfaces.
{% endtab %}
{% endtabs %}
<script src="{{ '/latest/platform/vm-assets/workflow-tabs.js' | relative_url }}" defer></script>

### Local development configuration and lifecycle

**Generated files.** The local builder writes root-owned, mode `0600` files under `/etc/x2a/`: `llm.env`, `aap.env`, and `auth.env`. All three are required; unused integrations get empty files. Values are literal `KEY=value` entries without shell expansion. For other options, see the [configuration reference]({% link latest/convertor-reference/configuration_options.md %}).

**Public URL.** For the local VM, edit `vm/charts/x2a/values.yaml` (`global.x2a.publicUrl`) before `make build`; for another host port, pass `HTTPS_PORT` to `make run`. OAuth callback URLs must match. This does not fix cloud TLS or provide public internet support.
