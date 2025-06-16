PODMAN = sudo podman

IMAGE_NAME = almalinux-bootc
VERSION_MAJOR = 10
PLATFORM = linux/amd64
LABELS ?=

# Component Versions - Ensure these are up-to-date
KUBE_VERSION          ?= 1.33.1
CONTAINERD_VERSION    ?= 2.1.2
CONTAINERD_SHA256     ?= 87c18b2686f38ee6f738492d04fc849f80567b7849d0710ee9d19fac3454adc4
CNI_PLUGINS_VERSION   ?= v1.7.1
CNI_PLUGINS_SHA256    ?= 1a28a0506bfe5bcdc981caf1a49eeab7e72da8321f1119b7be85f22621013098

# Derived image name for Kubernetes layer
IMAGE_KUBERNETES_NAME = $(IMAGE_NAME)-kube

.ONESHELL:
.PHONY: all
all: disk # 'all' will now build base, k8s layer, rechunk k8s, and create disk from k8s image

.PHONY: image
image: # Builds the base almalinux-bootc image
	$(PODMAN) build \
		--platform=$(PLATFORM) \
		--security-opt label=type:unconfined_t \
		--cap-add=all \
		--device /dev/fuse \
		--iidfile /tmp/image-id \
		$(LABELS) \
		-t $(IMAGE_NAME) \
		-f $(VERSION_MAJOR)/Containerfile \
		.

.PHONY: image-kubernetes
image-kubernetes: image # Depends on the base image 'localhost/almalinux-bootc:latest'
	$(PODMAN) build \
		--platform=$(PLATFORM) \
		--security-opt label=type:unconfined_t \
		--cap-add=all \
		--device /dev/fuse \
		--build-arg KUBE_VERSION=$(KUBE_VERSION) \
		--build-arg CONTAINERD_VERSION=$(CONTAINERD_VERSION) \
		--build-arg CONTAINERD_SHA256=$(CONTAINERD_SHA256) \
		--build-arg CNI_PLUGINS_VERSION=$(CNI_PLUGINS_VERSION) \
		--build-arg CNI_PLUGINS_SHA256=$(CNI_PLUGINS_SHA256) \
		--build-arg TARGETARCH=$(shell echo $(PLATFORM) | cut -d/ -f2) \
		$(LABELS) \
		-t $(IMAGE_KUBERNETES_NAME):$(KUBE_VERSION) \
		-f $(VERSION_MAJOR)/Containerfile.kubernetes \
		.
	$(PODMAN) tag $(IMAGE_KUBERNETES_NAME):$(KUBE_VERSION) $(IMAGE_KUBERNETES_NAME):latest
	echo "Kubernetes image $(IMAGE_KUBERNETES_NAME):$(KUBE_VERSION) built successfully via Containerfile."

.PHONY: rechunk
rechunk: image-kubernetes # Rechunk the Kubernetes image
	$(PODMAN) run \
		--rm --privileged \
		--security-opt label=type:unconfined_t \
		-v /var/lib/containers:/var/lib/containers:z \
		quay.io/centos-bootc/centos-bootc:stream10 \
		/usr/libexec/bootc-base-imagectl rechunk \
		localhost/$(IMAGE_KUBERNETES_NAME):latest localhost/rechunked-$(IMAGE_KUBERNETES_NAME):latest && \
	$(PODMAN) tag localhost/rechunked-$(IMAGE_KUBERNETES_NAME):latest $(IMAGE_KUBERNETES_NAME):latest && \
	$(PODMAN) rmi localhost/rechunked-$(IMAGE_KUBERNETES_NAME):latest

DISK_TYPE ?= iso
DISK_SIZE ?= 10G

.PHONY: disk
disk: rechunk # Create disk from the rechunked Kubernetes image
	mkdir -p images
	$(PODMAN) run \
		--rm --privileged \
		--security-opt label=type:unconfined_t \
		-v ./images:/output \
		-v ./$(VERSION_MAJOR)/almalinux-$(VERSION_MAJOR).toml:/config.toml:ro \
		-v /var/lib/containers/storage:/var/lib/containers/storage:z \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type $(DISK_TYPE) \
		--config /config.toml \
		--use-librepo=False \
		localhost/$(IMAGE_KUBERNETES_NAME):latest