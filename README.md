# Kubernetes Bootable Container Images

> [!WARNING]
> **This project is highly experimental and under active development. Use at your own risk.**

This repository provides a framework for building bootable OS images (ISOs, QCOW2s) for various Linux distributions using `bootc` and `podman`.

## Prerequisites

Ensure you have the following tools installed on your system:
- `make`
- `podman`
- `sudo` (build commands require elevated privileges)

## Project Structure

| Directory | Description |
|---|---|
| `builds/` | Output directory for generated ISO and QCOW2 files. |
| `configs/` | Configuration files (`.toml`) for the `bootc-image-builder`, defining users, passwords, disk size, etc. |
| `containerfiles/` | `Containerfile` definitions for each image variant. These extend from base images and add specific configurations and packages. |
| `manifests/` | `imagectl` manifests (`.yaml`) that define the core package sets for the base operating systems. |
| `overlay/` | Static configuration files that are copied directly into the image filesystem during the build process. |

## Configuration

The primary build configuration is managed through the `Makefile`.

### Kubernetes Version

To build the Kubernetes image with a specific version, edit the `K8S_VERSION` variable in the `Makefile`. The build script automatically handles using the full version for package installation and the major/minor version for the repository URL.

```makefile
# Makefile

# ...
K8S_VERSION := 1.33.1
# ...
```

## Building Images

All builds are orchestrated through the `Makefile`. Commands must be run from the root of the repository.

### Build All Images

To build all defined container images, ISOs, and QCOW2 files, run:

```bash
make all
```

### Build Individual Container Images

To build a specific container image, use its corresponding target. This is a prerequisite for building bootable media.

- **AlmaLinux 10 Base Image:**
  ```bash
  make almalinux10-base
  ```

- **AlmaLinux 10 Kubernetes Image:**
  ```bash
  make almalinux10-kube
  ```

### Build Bootable Media (ISO/QCOW2)

After building the desired container image, you can generate a bootable ISO or a QCOW2 virtual disk image.

- **AlmaLinux 10 Kubernetes ISO:**
  ```bash
  make almalinux10-kube-iso
  ```

- **AlmaLinux 10 Kubernetes QCOW2:**
  ```bash
  make almalinux10-kube-qcow2
  ```

### Clean Up

To remove all generated images from the local `podman` storage and the `builds/` directory, run:

```bash
make clean
```

This command converts the container image into a bootable `qcow2` file, which can be used directly by virtual machines.

```bash
sudo podman run --rm --privileged \
    --security-opt label=type:unconfined_t \
    -v ./images:/output \
    -v ./config.toml:/config.toml:ro \
    -v /var/lib/containers/storage:/var/lib/containers/storage:z \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type qcow2 \
    --config /config.toml \
    --local localhost/almalinux10-bootc:base
```

#### 4. Create a Bootable ISO Installer

This command attempts to create a bootable `iso` installer. This relies on the `bootc-image-builder` having a built-in, working definition for `almalinux-10`.

```bash
sudo podman run --rm --privileged \
    --security-opt label=type:unconfined_t \
    -v ./images:/output \
    -v ./config.toml:/config.toml:ro \
    -v /var/lib/containers/storage:/var/lib/containers/storage:z \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type iso \
    --config /config.toml \
    --local localhost/almalinux10-bootc:base
```