#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.0.0}"
ARCH="${2:-x86_64}"
DATA_DIR="${3:-game-data/data}"

REPO_DIR="$(pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cd "$WORK_DIR"

echo "=== Cloning NXEngine-evo ==="
git clone --depth=1 "$NXENGINE_REPO" nxengine-evo
cd nxengine-evo

echo "=== Building NXEngine-evo (Linux ${ARCH}) ==="
cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DPORTABLE=ON -Bbuild -H.
ninja -C build

echo "=== Assembling AppDir ==="
rm -rf AppDir
mkdir -p AppDir/usr/bin AppDir/usr/share/applications \
	AppDir/usr/share/icons/hicolor/256x256/apps AppDir/usr/share/metainfo
cp build/nxengine-evo build/nxextract AppDir/usr/bin/
cp -r "$REPO_DIR/$DATA_DIR" AppDir/usr/bin/data
cp platform/xdg/org.nxengine.nxengine_evo.desktop AppDir/usr/share/applications/
cp platform/xdg/org.nxengine.nxengine_evo.png AppDir/usr/share/icons/hicolor/256x256/apps/
cp platform/xdg/org.nxengine.nxengine_evo.appdata.xml AppDir/usr/share/metainfo/
chmod +x AppDir/usr/bin/nxengine-evo AppDir/usr/bin/nxextract

echo "=== Building AppImage (${ARCH}) ==="
export APPIMAGE_EXTRACT_AND_RUN=1
export ARCH="$ARCH"
export OUTPUT="NXEngine-Evo-${VERSION}-Linux-${ARCH}.AppImage"
export PATH="$(pwd):$PATH"

LD="linuxdeploy-${ARCH}.AppImage"
wget -q "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/${LD}" -O "$LD"
chmod +x "$LD"
wget -q "https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-${ARCH}.AppImage" -O "linuxdeploy-plugin-appimage.AppImage"
chmod +x "linuxdeploy-plugin-appimage.AppImage"

"./$LD" --appdir AppDir --output appimage

mkdir -p "$REPO_DIR/dist"
cp "$OUTPUT" "$REPO_DIR/dist/"

echo "=== Linux dist ready ==="
ls -la "$REPO_DIR/dist"
