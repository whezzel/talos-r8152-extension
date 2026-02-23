# Talos r8152/r8157 Extension

[![Talos Compatibility](https://img.shields.io/badge/Talos-%3E%3Dv1.10.0-blue)](https://talos.dev)

A Talos Linux extension that provides the Realtek r8152 Ethernet driver with support for r8157 devices.

## Description

This extension enables support for Realtek r8152/r8157 USB Ethernet adapters in Talos Linux clusters. It builds a signed kernel module package from the latest upstream driver source and packages it as a Talos extension for easy deployment.

## Features

- **Latest Driver Support**: Automatically fetches and builds the latest r8152 driver from [wget/realtek-r8152-linux](https://github.com/wget/realtek-r8152-linux)
- **r8157 Compatibility**: Includes support for r8157 devices
- **Signed Modules**: Builds signed kernel modules for secure boot compatibility
- **Automated Builds**: Script automatically detects Talos versions and driver releases
- **Container Registry**: Publishes to GitHub Container Registry (ghcr.io)

## Prerequisites

- Linux build environment (tested on Arch Linux)
- `jq` and `yq` tools:
  ```bash
  sudo pacman -S jq yq  # Arch Linux
  # or equivalent for your distro
  ```
- GitHub Container Registry access (ghcr.io)
- Docker for building (handled by build script)

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/whezzel/talos-r8152-extension.git
   cd talos-r8152-extension
   ```

2. **Set up environment:**
   ```bash
   cp .env.example .env
   # Edit .env and set USERNAME=whezzel (or your ghcr.io username)
   ```

3. **Build the extension:**
   ```bash
   ./build.sh  # Uses latest stable Talos version
   # or specify version: ./build.sh v1.10.0
   ```

The script will:
- Detect the latest Talos version (if not specified)
- Fetch the latest r8152 driver release
- Build and push the kernel module package
- Build and push the extension image

## Detailed Build Instructions

### Environment Setup

Create a `.env` file from the example:
```bash
cp .env.example .env
```

Edit `.env` to set your GitHub Container Registry username:
```env
USERNAME=your-ghcr-username
```

### Building

Run the build script with optional parameters:

```bash
./build.sh [TALOS_VERSION] [CUSTOM_TAG]
```

**Parameters:**
- `TALOS_VERSION`: Talos version (e.g., `v1.10.0`). If omitted, uses latest stable.
- `CUSTOM_TAG`: Custom image tag. If omitted, uses `TALOS_VERSION-DRIVER_VERSION`.

**Examples:**
```bash
# Build for latest stable Talos with auto-detected driver
./build.sh

# Build for specific Talos version
./build.sh v1.10.0

# Build with custom tag
./build.sh v1.10.0 my-custom-tag
```

### What the Build Does

1. **Auto-detection**: Fetches latest Talos stable release if no version specified
2. **Driver Fetching**: Downloads latest r8152 driver tarball and computes fresh SHA256/SHA512 hashes
3. **Package Build**: Clones `siderolabs/pkgs`, builds signed kernel module package
4. **Extension Build**: Clones `siderolabs/extensions`, builds thin extension using the package
5. **Registry Push**: Pushes both images to `ghcr.io/$USERNAME/`

## Usage in Talos

After building, use the extension image in your Talos cluster configuration:

```yaml
# In your talosconfig or machine config
machine:
  kernel:
    modules:
      - name: r8152
  systemExtensions:
    - image: ghcr.io/whezzel/realtek-r8152:v1.10.0-v2.21.4
```

Apply the configuration to your cluster:
```bash
talosctl apply-config --insecure --nodes <node-ip> --file config.yaml
```

## Customization

### Override Driver Version

The build script automatically uses the latest driver release. To pin a specific version, modify the `LATEST_DRIVER_TAG` variable in `build.sh`.

### Branch Selection

The script automatically selects the appropriate Talos branch:
- `main` for alpha/beta/rc versions
- `release-X.Y` for stable versions

### Platform Support

Currently builds for `linux/amd64`. Modify the `PLATFORM` variable in `build.sh` for other architectures.

## Troubleshooting

### Authentication Issues
Ensure your `.env` file contains the correct `USERNAME` and you have push access to `ghcr.io/$USERNAME/`.

### Missing Tools
Install required dependencies:
```bash
sudo pacman -S jq yq  # Arch Linux
```

### Build Failures
- Check that the specified Talos version exists
- Verify network connectivity for GitHub API calls
- Ensure Docker/Podman is running and accessible

### Extension Not Loading
- Verify the extension image exists in your registry
- Check Talos logs: `talosctl logs --nodes <node-ip>`
- Ensure kernel module is properly signed for secure boot

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the build process
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Sidero Labs](https://siderolabs.com/) for Talos Linux and the extension framework
- [wget](https://github.com/wget) for maintaining the r8152 driver
- Realtek for the original driver source
