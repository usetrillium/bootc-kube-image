# AlmaLinux Kubernetes Bootable Container Images (bootc)

**<ins>Caution</ins>: Kubernetes bootc images are currently *experimental*. Please use with care and report any issues.**

## Project Overview

This project automates the build of a secure, parameterized AlmaLinux 10 Kubernetes bootable container image using `bootc`. The goal is to produce a bootable ISO installer that can be used to deploy Kubernetes nodes.

The process involves:
1. Building a base AlmaLinux 10 bootc-enabled container image.
2. Layering Kubernetes components (kubelet, kubeadm, kubectl) and a container runtime (containerd) onto the base image.
3. Generating a bootable ISO from the final Kubernetes-enabled container image.

## Prerequisites

- Podman (or Docker, though Makefile is configured for Podman)
- Make
- Internet access (for downloading packages and base images)
- `sudo` access (for running Podman builds and mounting operations if necessary)

## Directory Structure

```
.
├── 10/                             # AlmaLinux 10 specific files
│   ├── Containerfile               # Builds the base AlmaLinux 10 bootc image
│   ├── Containerfile.kubernetes    # Layers Kubernetes on the base image
│   ├── almalinux-10.yaml         # Manifest for bootc-base-imagectl (base image)
│   └── almalinux-10.toml         # Configuration for bootc-image-builder (ISO/disk image)
├── images/                         # Output directory for generated ISOs/disk images (gitignored)
├── ansible/                        # Ansible roles and playbooks for configuration (if used)
├── Makefile                        # Main build orchestration file
├── README.md                       # This file
└── .gitignore                      # Specifies intentionally untracked files
```

## Build Instructions

The `Makefile` provides targets to build the images and the final ISO.

### Variables

The following variables can be overridden when calling `make`:

- `PLATFORM`: Target platform (default: `linux/amd64`).
- `IMAGE_NAME`: Base name for the bootc image (default: `almalinux-bootc`).
- `IMAGE_KUBERNETES_NAME`: Name for the Kubernetes layered image (default: `almalinux-bootc-kube`).
- `VERSION_MAJOR`: Major version of AlmaLinux (default: `10`).
- `KUBE_VERSION`: Kubernetes version (e.g., `1.33.1`).
- `CONTAINERD_VERSION`: Containerd version (e.g., `2.1.2`).
- `CNI_PLUGINS_VERSION`: CNI plugins version (e.g., `v1.7.1`).
- `DISK_TYPE`: Type of disk image to create with `make disk` (default: `iso`, can be `qcow2`).
- `DISK_SIZE`: Size of the disk image (default: `10G`).

Example: `sudo make KUBE_VERSION=1.30.2 disk`

### Targets

1.  **Build Base AlmaLinux Bootc Image:**
    ```bash
    sudo make image
    ```
    This creates a container image named `localhost/almalinux-bootc:latest` (or as per `IMAGE_NAME`).

2.  **Build Kubernetes Layered Image:**
    ```bash
    sudo make image-kubernetes
    ```
    This depends on the base image and creates `localhost/almalinux-bootc-kube:latest` (or as per `IMAGE_KUBERNETES_NAME` and `KUBE_VERSION`).

3.  **Rechunk the Kubernetes Image (Optional but Recommended for bootc disk images):**
    The `disk` target depends on `rechunk`, which optimizes the image for `bootc-image-builder`.
    ```bash
    sudo make rechunk
    ```

4.  **Create Bootable Disk Image (ISO or QCOW2):**
    ```bash
    sudo make disk
    ```
    This will produce an `install.iso` (by default) or `install.qcow2` in the `images/` directory.
    To specify qcow2: `sudo make disk DISK_TYPE=qcow2`

## Customization

-   **Component Versions:** Kubernetes, Containerd, and CNI plugin versions are controlled by variables in the `Makefile`. Modify these variables at the top of the `Makefile` or override them on the command line.
-   **Kickstart Configuration:** The `10/almalinux-10.toml` file contains a Kickstart section (`[customizations.installer.kickstart]`) that defines users, passwords (encrypted recommended), services, partitioning, etc., for the ISO installer. Modify this to suit your needs.
-   **System Configuration:** Additional system files (kernel modules, sysctl params, systemd units/presets) are also managed in `10/almalinux-10.toml` via `[[customizations.files]]` and `[[customizations.directories]]`.

## Output

-   Container Images: Stored in your local Podman/Docker storage (e.g., `localhost/almalinux-bootc:latest`, `localhost/almalinux-bootc-kube:1.33.1`).
-   Disk Image: An `install.iso` or `install.qcow2` file in the `images/` directory.

## Troubleshooting

-   **Docker CE Repository 404 Error (AlmaLinux 10):**
    If you encounter errors fetching `repomd.xml` from `download.docker.com/linux/centos/10.0/...`, it's because Docker doesn't yet provide a CentOS 10 repository. The `10/Containerfile.kubernetes` now includes a step to modify `/etc/yum.repos.d/docker-ce.repo` to use the CentOS 9 channel (`sed -i 's/$releasever/9/' ...`), which is generally compatible for installing `containerd.io`.
-   **bootc-image-builder file copy errors:**
    If `bootc-image-builder` (run via `make disk`) fails with errors like `cp: cannot create regular file '/run/osbuild/tree/etc/some/path': No such file or directory`, ensure the parent directory (e.g., `/etc/some/`) is explicitly created in `10/almalinux-10.toml` using a `[[customizations.directories]]` block before the `[[customizations.files]]` block that tries to place a file in `path`.