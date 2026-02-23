#!/usr/bin/env bash
set -euo pipefail

# Load secrets
if [ -f .env ]; then
  source .env
else
  echo "❌ Copy .env.example to .env and set USERNAME=whezzel"
  exit 1
fi

# Dependency check
command -v jq >/dev/null || { echo "❌ jq missing → sudo pacman -S jq"; exit 1; }
command -v yq >/dev/null || { echo "❌ yq missing → sudo pacman -S yq"; exit 1; }

# === TALOS VERSION & BRANCH AUTO-DETECTION ===
if [ $# -eq 0 ]; then
  echo "🔍 No Talos version given → fetching latest stable..."
  TALOS_VERSION=$(curl -s https://api.github.com/repos/siderolabs/talos/releases/latest | jq -r '.tag_name')
  echo "   Latest stable: $TALOS_VERSION"
elif [ $# -eq 1 ] || [ $# -eq 2 ]; then
  TALOS_VERSION="$1"
else
  echo "Usage: $0 [TALOS_VERSION] [CUSTOM_TAG]"
  exit 1
fi

TALOS_VERSION=${TALOS_VERSION#v}
if [[ $TALOS_VERSION == *alpha* ]] || [[ $TALOS_VERSION == *beta* ]] || [[ $TALOS_VERSION == *rc* ]]; then
  TALOS_BRANCH="main"
else
  MAJOR_MINOR=$(echo "$TALOS_VERSION" | cut -d. -f1,2)
  TALOS_BRANCH="release-${MAJOR_MINOR}"
fi

# === AUTO-FETCH LATEST DRIVER + CHECKSUMS ===
echo "🔍 Fetching latest r8152 driver..."
LATEST_DRIVER_TAG=$(curl -s https://api.github.com/repos/wget/realtek-r8152-linux/releases/latest | jq -r '.tag_name')
[[ -z "$LATEST_DRIVER_TAG" || "$LATEST_DRIVER_TAG" == "null" ]] && LATEST_DRIVER_TAG="v2.21.4"

echo "📦 Using driver version: $LATEST_DRIVER_TAG"

TARBALL_URL="https://github.com/wget/realtek-r8152-linux/archive/refs/tags/${LATEST_DRIVER_TAG}.tar.gz"
TEMP_TARBALL=$(mktemp --suffix=.tar.gz)
curl -L -f -o "$TEMP_TARBALL" "$TARBALL_URL"

SHA256=$(sha256sum "$TEMP_TARBALL" | awk '{print $1}')
SHA512=$(sha512sum "$TEMP_TARBALL" | awk '{print $1}')
rm -f "$TEMP_TARBALL"

echo "✅ Fresh hashes computed"

if [ -z "${2:-}" ]; then
  TAG="${TALOS_VERSION}-${LATEST_DRIVER_TAG}"
else
  TAG="$2"
fi

echo "🚀 Building Talos r8152/r8157 extension"
echo "   Talos version : v$TALOS_VERSION"
echo "   Branch        : $TALOS_BRANCH"
echo "   Image tag     : $TAG"

# === 1. Build signed kmod in pkgs ===
echo "📦 Building signed realtek-r8152-pkg..."
rm -rf pkgs-temp && mkdir -p pkgs-temp
git clone --depth 1 --branch "$TALOS_BRANCH" https://github.com/siderolabs/pkgs.git pkgs-temp
cd pkgs-temp

cp -r ../pkgs/realtek-r8152-pkg .

# Auto-update driver version + hashes
PKG_YAML="realtek-r8152-pkg/pkg.yaml"
sed -i "s|refs/tags/[^/]*\.tar\.gz|refs/tags/${LATEST_DRIVER_TAG}.tar.gz|g" "$PKG_YAML"
sed -i "s|sha256: .*|sha256: $SHA256|g" "$PKG_YAML"
sed -i "s|sha512: .*|sha512: $SHA512|g" "$PKG_YAML"

git remote set-url origin https://github.com/siderolabs/pkgs.git

yq -i -y '(select(.kind == "pkgfile.Build").spec.targets) += ["realtek-r8152-pkg"]' .kres.yaml || true

echo "🔍 Verifying pkgs target:"
grep -q "realtek-r8152-pkg" .kres.yaml && echo "✅ Target added" || echo "❌ Target missing"

make rekres

make realtek-r8152-pkg \
  REGISTRY=ghcr.io \
  USERNAME="$USERNAME" \
  TAG="$TAG" \
  PLATFORM=linux/amd64 \
  PUSH=true

PKG_IMAGE="ghcr.io/$USERNAME/realtek-r8152-pkg:$TAG"
cd ..

# === 2. Build thin extension ===
echo "📦 Building realtek-r8152 extension..."
rm -rf extensions-temp && mkdir -p extensions-temp
git clone --depth 1 --branch "$TALOS_BRANCH" https://github.com/siderolabs/extensions.git extensions-temp
cd extensions-temp

cp -r ../extensions/realtek-r8152 .

sed -i "s|PKG_IMAGE_PLACEHOLDER|$PKG_IMAGE|g" realtek-r8152/pkg.yaml

git remote set-url origin https://github.com/siderolabs/extensions.git

yq -i -y '(select(.kind == "pkgfile.Build").spec.targets) += ["realtek-r8152"]' .kres.yaml || true

echo "🔍 Verifying extensions target:"
grep -q "realtek-r8152" .kres.yaml && echo "✅ Target added" || echo "❌ Target missing"

make rekres

make realtek-r8152 \
  REGISTRY=ghcr.io \
  USERNAME="$USERNAME" \
  TAG="$TAG" \
  PLATFORM=linux/amd64 \
  PUSH=true

echo "🎉 SUCCESS!"
echo "✅ Extension ready → ghcr.io/$USERNAME/realtek-r8152:$TAG"
