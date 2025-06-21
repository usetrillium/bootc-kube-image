# Makefile for building bootable container images

# Image tags
ROCKY10_BASE_TAG := localhost/rocky10-bootc:base
ROCKY10_DESKTOP_TAG := localhost/rocky10-bootc:desktop
ALMALINUX10_BASE_TAG := localhost/almalinux10-bootc:base
ALMALINUX10_DESKTOP_TAG := localhost/almalinux10-bootc:desktop
ALMALINUX10_KUBE_TAG := localhost/almalinux10-bootc:kube

# Versions
K8S_VERSION := 1.33.1
K8S_REGISTRY := registry.k8s.io
PAUSE_IMAGE_VERSION := 3.10
CONTAINERD_CRI_SOCKET := /var/run/containerd/containerd.sock

# Config files
ROCKY10_CONFIG := ./configs/rockylinux-10.toml
ALMALINUX10_CONFIG := ./configs/almalinux-10.toml
ALMALINUX10_DESKTOP_CONFIG := ./configs/almalinux-10-desktop.toml
ALMALINUX10_KUBE_CONFIG := ./configs/almalinux-10-kube.toml

# Directories
OUTPUT_DIR := ./images

# Default target builds the qcow2 images for the main desktop and server images
all: rocky10-desktop-qcow2 almalinux10-desktop-qcow2 almalinux10-kube-qcow2

# Phony targets prevent conflicts with files of the same name
.PHONY: all clean \
	# Container image targets
	rocky10-base rocky10-desktop almalinux10-base almalinux10-desktop almalinux10-kube \
	# Rechunk targets
	rocky10-desktop-rechunk almalinux10-desktop-rechunk almalinux10-kube-rechunk \
	# QCOW2 targets
	rocky10-desktop-qcow2 almalinux10-base-qcow2 almalinux10-desktop-qcow2 almalinux10-kube-qcow2 \
	# ISO targets
	rocky10-desktop-iso almalinux10-base-iso almalinux10-desktop-iso almalinux10-kube-iso

# --- Container Image Builds ---

rocky10-base:
	@echo "--> Building Rocky Linux 10 base container..."
	sudo podman build --security-opt label=type:unconfined_t --cap-add=all --device /dev/fuse --iidfile /tmp/image-id -t $(ROCKY10_BASE_TAG) -f containerfiles/rockylinux/10/Containerfile.base .

rocky10-desktop: rocky10-base
	@echo "--> Building Rocky Linux 10 desktop container..."
	sudo podman build --security-opt label=type:unconfined_t --cap-add=all --device /dev/fuse --iidfile /tmp/image-id -t $(ROCKY10_DESKTOP_TAG) -f containerfiles/rockylinux/10/Containerfile.desktop .

almalinux10-base:
	@echo "--> Building AlmaLinux 10 base container..."
	sudo podman build --security-opt label=type:unconfined_t --cap-add=all --device /dev/fuse --iidfile /tmp/image-id -t $(ALMALINUX10_BASE_TAG) -f containerfiles/almalinux/10/Containerfile.base .

almalinux10-desktop: almalinux10-base
	@echo "--> Building AlmaLinux 10 desktop container..."
	sudo podman build --security-opt label=type:unconfined_t --cap-add=all --device /dev/fuse --iidfile /tmp/image-id -t $(ALMALINUX10_DESKTOP_TAG) -f containerfiles/almalinux/10/Containerfile.desktop .

almalinux10-kube: almalinux10-base
	@echo "--> Building AlmaLinux 10 Kube container..."
		sudo podman build --security-opt label=type:unconfined_t --cap-add=all --device /dev/fuse --iidfile /tmp/image-id --build-arg K8S_VERSION=$(K8S_VERSION) --build-arg K8S_REGISTRY=$(K8S_REGISTRY) --build-arg PAUSE_IMAGE_VERSION=$(PAUSE_IMAGE_VERSION) --build-arg CONTAINERD_CRI_SOCKET=$(CONTAINERD_CRI_SOCKET) -t $(ALMALINUX10_KUBE_TAG) -f containerfiles/almalinux/10/Containerfile.kubernetes .

# --- Rechunking ---

almalinux10-desktop-rechunk: almalinux10-desktop
	@echo "--> Rechunking AlmaLinux 10 desktop image..."
	sudo podman run \
		--rm --privileged \
		--security-opt label=type:unconfined_t \
		-v /var/lib/containers/storage:/var/lib/containers/storage:z \
		quay.io/centos-bootc/centos-bootc:stream10 \
		/usr/libexec/bootc-base-imagectl rechunk \
		$(ALMALINUX10_DESKTOP_TAG) localhost/rechunked-almalinux10-desktop:latest && \
	sudo podman tag localhost/rechunked-almalinux10-desktop:latest $(ALMALINUX10_DESKTOP_TAG) && \
	sudo podman rmi localhost/rechunked-almalinux10-desktop:latest

almalinux10-kube-rechunk: almalinux10-kube
	@echo "--> Rechunking AlmaLinux 10 kube image..."
	sudo podman run \
		--rm --privileged \
		--security-opt label=type:unconfined_t \
		-v /var/lib/containers/storage:/var/lib/containers/storage:z \
		quay.io/centos-bootc/centos-bootc:stream10 \
		/usr/libexec/bootc-base-imagectl rechunk \
		$(ALMALINUX10_KUBE_TAG) localhost/rechunked-almalinux10-kube:latest && \
	sudo podman tag localhost/rechunked-almalinux10-kube:latest $(ALMALINUX10_KUBE_TAG) && \
	sudo podman rmi localhost/rechunked-almalinux10-kube:latest

rocky10-desktop-rechunk: rocky10-desktop
	@echo "--> Rechunking Rocky Linux 10 desktop image..."
	sudo podman run \
		--rm --privileged \
		--security-opt label=type:unconfined_t \
		-v /var/lib/containers/storage:/var/lib/containers/storage:z \
		quay.io/centos-bootc/centos-bootc:stream10 \
		/usr/libexec/bootc-base-imagectl rechunk \
		$(ROCKY10_DESKTOP_TAG) localhost/rechunked-rocky10-desktop:latest && \
	sudo podman tag localhost/rechunked-rocky10-desktop:latest $(ROCKY10_DESKTOP_TAG) && \
	sudo podman rmi localhost/rechunked-rocky10-desktop:latest

# --- QCOW2 Image Builds ---

almalinux10-kube-qcow2: almalinux10-kube-rechunk
	@echo "--> Building AlmaLinux 10 kube qcow2 image..."
	sudo podman run --rm --privileged \
		--security-opt label=type:unconfined_t \
		-v $(OUTPUT_DIR):/output \
		-v $(ALMALINUX10_KUBE_CONFIG):/config.toml:ro \
		-v /var/lib/containers/storage:/var/lib/containers/storage:z \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type qcow2 \
		--config /config.toml \
		--local $(ALMALINUX10_KUBE_TAG)

almalinux10-desktop-qcow2: almalinux10-desktop-rechunk
	@echo "--> Building AlmaLinux 10 desktop qcow2 image..."
	sudo podman run --rm --privileged \
		--security-opt label=type:unconfined_t \
		-v $(OUTPUT_DIR):/output \
		-v $(ALMALINUX10_DESKTOP_CONFIG):/config.toml:ro \
		-v /var/lib/containers/storage:/var/lib/containers/storage:z \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type qcow2 \
		--config /config.toml \
		--local $(ALMALINUX10_DESKTOP_TAG)

rocky10-desktop-qcow2: rocky10-desktop-rechunk
	@echo "--> Building Rocky Linux 10 desktop qcow2 image..."
	sudo podman run --rm --privileged \
		--security-opt label=type:unconfined_t \
		-v $(OUTPUT_DIR):/output \
		-v $(ROCKY10_CONFIG):/config.toml:ro \
		-v /var/lib/containers/storage:/var/lib/containers/storage:z \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type qcow2 \
		--config /config.toml \
		--local $(ROCKY10_DESKTOP_TAG)

almalinux10-base-qcow2: almalinux10-base
	@echo "--> Building AlmaLinux 10 base qcow2 image..."
	sudo podman run --rm --privileged \
		--security-opt label=type:unconfined_t \
		-v $(OUTPUT_DIR):/output \
		-v $(ALMALINUX10_CONFIG):/config.toml:ro \
		-v /var/lib/containers/storage:/var/lib/containers/storage:z \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type qcow2 \
		--config /config.toml \
		--local $(ALMALINUX10_BASE_TAG)

# --- ISO Image Builds ---

almalinux10-kube-iso: almalinux10-kube-rechunk
	@echo "--> Building AlmaLinux 10 Kube ISO..."
	sudo podman run --rm --privileged \
		--security-opt label=type:unconfined_t \
		-v $(OUTPUT_DIR):/output \
		-v $(ALMALINUX10_KUBE_CONFIG):/config.toml:ro \
		-v /var/lib/containers/storage:/var/lib/containers/storage:z \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type iso \
		--config /config.toml \
		--use-librepo=False \
		--local $(ALMALINUX10_KUBE_TAG)

almalinux10-desktop-iso: almalinux10-desktop-rechunk
	@echo "--> Building AlmaLinux 10 desktop ISO..."
	sudo podman run --rm --privileged \
		--security-opt label=type:unconfined_t \
		-v $(OUTPUT_DIR):/output \
		-v $(ALMALINUX10_DESKTOP_CONFIG):/config.toml:ro \
		-v /var/lib/containers/storage:/var/lib/containers/storage:z \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type iso \
		--config /config.toml \
		--use-librepo=False \
		--local $(ALMALINUX10_DESKTOP_TAG)

rocky10-desktop-iso: rocky10-desktop-rechunk
	@echo "--> Building Rocky Linux 10 desktop ISO..."
	sudo podman run --rm --privileged \
		--security-opt label=type:unconfined_t \
		-v $(OUTPUT_DIR):/output \
		-v $(ROCKY10_CONFIG):/config.toml:ro \
		-v ./manifests/rockylinux/10/iso-def.yaml:/usr/share/bootc-image-builder/defs/rocky-10.0.yaml:ro \
		-v /var/lib/containers/storage:/var/lib/containers/storage:z \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type iso \
		--config /config.toml \
		--local $(ROCKY10_DESKTOP_TAG)

almalinux10-base-iso: almalinux10-base
	@echo "--> Building AlmaLinux 10 base ISO..."
	sudo podman run --rm --privileged \
		--security-opt label=type:unconfined_t \
		-v $(OUTPUT_DIR):/output \
		-v $(ALMALINUX10_CONFIG):/config.toml:ro \
		-v /var/lib/containers/storage:/var/lib/containers/storage:z \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type iso \
		--config /config.toml \
		--use-librepo=False \
		--local $(ALMALINUX10_BASE_TAG)

# --- Clean Target ---

clean:
	@echo "--> Cleaning up container images and output directory..."
	-sudo podman rmi $(ROCKY10_BASE_TAG) $(ROCKY10_DESKTOP_TAG) $(ALMALINUX10_BASE_TAG) $(ALMALINUX10_DESKTOP_TAG) $(ALMALINUX10_KUBE_TAG)
	-sudo rm -rf $(OUTPUT_DIR)/*
	@echo "Clean complete."
