IMAGE ?= localhost/kind-vm
IMAGE_BUILDER ?= ghcr.io/osbuild/image-builder-cli:latest
EXPORT_TYPE ?= ami
EXPORT_DIR ?= output
AWS_IMAGE ?= $(EXPORT_DIR)/image/disk.raw
AWS_ARCH ?= $(shell uname -m)
ROOTFUL_PODMAN ?= sudo podman
ROOTFUL_PODMAN_BUILD_ARGS ?=
ROOTFUL_CONTAINER_STORAGE ?= /var/lib/containers/storage
AWS_PROFILE ?= default
AWS_CONFIG_DIR ?= $(HOME)/.aws
VM_NAME ?= kind-vm
CPUS ?= 4
MEMORY ?= 16G
HTTPS_PORT ?= 8443

DISK_SIZE ?= 60G
FILESYSTEM ?= btrfs
CLOUD_INIT_DIR ?= cloud-init
CLOUD_INIT_PORT ?= 8000
# Lazy expansion: only VM creation and seed serving need host IPv4 detection.
HOST_IFACE ?= $(shell ip -j -4 route show default 2>/dev/null | jq -r 'sort_by(.metric // 0) | .[0].dev // empty' 2>/dev/null)
HOST_IP ?= $(shell ip -j -4 address show dev "$(HOST_IFACE)" up 2>/dev/null | jq -r '[.[].addr_info[] | select(.scope == "global") | .local][0] // empty' 2>/dev/null)

# Build dependencies in a temporary copy, keeping charts/ source-only.
# Use HELM_ARGS='--dry-run=server ...' to include keys from live Secrets.
HELM_ARGS ?=
.PHONY: render
render:
	@set -eu; work=$$(mktemp -d); trap 'rm -rf "$$work"' EXIT; \
	cp -a charts/x2a "$$work/chart"; \
	export HELM_CACHE_HOME="$$work/cache" HELM_CONFIG_HOME="$$work/config" HELM_DATA_HOME="$$work/data"; \
	helm repo add rhdh https://redhat-developer.github.io/rhdh-chart; \
	helm dependency build "$$work/chart"; \
	helm template rhdh "$$work/chart" --namespace rhdh $(HELM_ARGS) > "$$work/render.yaml"; \
	cp "$$work/render.yaml" render_helm.yaml
	@echo 'Rendered full manifests to render_helm.yaml'

.PHONY: build export publish-aws-ami run ssh start stop virt-run virt-ssh virt-serve virt-destroy
build:
	podman build -t $(IMAGE) -f Containerfile .

# Export the bootc image as an AMI artifact; image-builder requires rootful Podman.
export:
	$(ROOTFUL_PODMAN) build $(ROOTFUL_PODMAN_BUILD_ARGS) -t $(IMAGE) -f Containerfile .
	mkdir -p $(EXPORT_DIR)/image
	$(ROOTFUL_PODMAN) run --rm --privileged --pull=newer \
		--security-opt label=type:unconfined_t \
		-v $(ROOTFUL_CONTAINER_STORAGE):/var/lib/containers/storage \
		-v $(CURDIR)/$(EXPORT_DIR):/output \
		$(IMAGE_BUILDER) build \
			--bootc-ref $(IMAGE) \
			--bootc-default-fs $(FILESYSTEM) \
			--output-dir /output/image \
			--output-name disk \
			$(EXPORT_TYPE)

# Upload an existing raw disk as a new AMI; no image build.
publish-aws-ami:
	podman run --rm \
		--security-opt label=disable \
		-v "$(abspath $(AWS_IMAGE)):/images/disk.raw:ro" \
		-v "$(AWS_CONFIG_DIR):/root/.aws:ro" \
		$(IMAGE_BUILDER) upload /images/disk.raw --to aws \
		--arch "$(AWS_ARCH)" \
		--aws-profile "$(AWS_PROFILE)" \
		--aws-ami-name "$(AWS_AMI_NAME)" \
		--aws-bucket "$(AWS_BUCKET)" \
		--aws-region "$(AWS_REGION)"

# The short names always refer to the persistent libvirt VM.
run: virt-run

ssh: virt-ssh

start:
	bcvk libvirt start $(VM_NAME)

stop:
	bcvk libvirt stop $(VM_NAME)

# The backslash must reach GRUB, not just protect the host shell's semicolon.
virt-run:
	@command -v bcvk >/dev/null || { echo 'Install the Fedora bcvk package on the host first.'; exit 1; }
	@test -n "$(HOST_IP)" || { echo 'Cannot detect host IPv4. Install iproute/jq, or set HOST_IP=... (optionally HOST_IFACE=...).'; exit 1; }
	@test -r "$(CLOUD_INIT_DIR)/user-data" -a -r "$(CLOUD_INIT_DIR)/meta-data" || { echo 'Missing cloud-init user-data or meta-data.'; exit 1; }
	@echo 'Cloud-init seed: http://$(HOST_IP):$(CLOUD_INIT_PORT)/ (keep make virt-serve running)'
	bcvk libvirt run \
		--name $(VM_NAME) \
		--filesystem $(FILESYSTEM) \
		--cpus $(CPUS) --memory $(MEMORY) --disk-size $(DISK_SIZE) \
		--port $(HTTPS_PORT):443 \
		--karg "ds=nocloud\;s=http://$(HOST_IP):$(CLOUD_INIT_PORT)/" \
		--karg "console=ttyS0,115200n8" \
		--detach \
		$(IMAGE)
	@echo 'Persistent VM launched. Connect with: make ssh VM_NAME=$(VM_NAME)'
	@echo 'RHDH URL is set in charts/x2a/values.yaml (development certificate); wait for /opt/x2a/status.sh to report READY.'

virt-ssh:
	bcvk libvirt ssh $(VM_NAME)

# Permanently remove the VM and its resources; keep bcvk's confirmation prompt.
virt-destroy:
	bcvk libvirt rm --force --stop $(VM_NAME)

virt-serve:
	@test -n "$(HOST_IP)" || { echo 'Cannot detect host IPv4. Install iproute/jq, or set HOST_IP=... (optionally HOST_IFACE=...).'; exit 1; }
	@test -r "$(CLOUD_INIT_DIR)/user-data" -a -r "$(CLOUD_INIT_DIR)/meta-data" || { echo 'Missing cloud-init user-data or meta-data.'; exit 1; }
	@echo 'Serving cloud-init at http://$(HOST_IP):$(CLOUD_INIT_PORT)/; Ctrl-C to stop.'
	python3 -m http.server $(CLOUD_INIT_PORT) --bind "$(HOST_IP)" --directory "$(CLOUD_INIT_DIR)"
