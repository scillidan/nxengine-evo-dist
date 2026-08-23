#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.0.0}"
ARCH="${2:-aarch64}"
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

echo "=== Assembling RetroPie ports package ==="
STAGE_DIR="$WORK_DIR/nxengine-evo"
mkdir -p "$STAGE_DIR"
cp build/nxengine-evo "$STAGE_DIR/nxengine-evo"
cp -r "$REPO_DIR/$DATA_DIR" "$STAGE_DIR/data"

cat >"$STAGE_DIR/nxengine-evo.sh" <<'EOF'
#!/usr/bin/env bash
dir="$(cd "$(dirname "$0")" && pwd)"
cd "$dir"
exec ./nxengine-evo "$@"
EOF
chmod +x "$STAGE_DIR/nxengine-evo.sh"

cat >"$STAGE_DIR/README.txt" <<EOF
NXEngine-Evo ${VERSION} - RetroPie ports package

Install:
  1. Copy (unzip) the nxengine-evo folder into
     ~/RetroPie/roms/ports/
  2. Restart EmulationStation. The game appears under
     Ports > nxengine-evo.

Requires a 64-bit (aarch64) RetroPie installation.
The binary and its data/ directory must stay in the same
folder; saves go to ~/.local/share/nxengine.

Controls can be configured in-game (Settings menu).
EOF

echo "=== Packaging RetroPie ports zip ==="
mkdir -p "$REPO_DIR/dist"
OUTPUT="$REPO_DIR/dist/NXEngine-Evo-${VERSION}-RetroPie-ports.zip"
rm -f "$OUTPUT"
cd "$WORK_DIR"
zip -r "$OUTPUT" nxengine-evo

echo "=== RetroPie ports dist ready ==="
ls -la "$REPO_DIR/dist"
