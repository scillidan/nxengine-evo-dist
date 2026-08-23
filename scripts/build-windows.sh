#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.0.0}"
DATA_DIR="${2:-game-data/data}"

REPO_DIR="$(pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

copy_runtime_dlls() {
	local exe="$1" dest="$2"
	local dll
	for dll in $(objdump -p "$exe" | sed -n 's/.*DLL Name: //p'); do
		if [ -f "/mingw64/bin/$dll" ] && [ ! -e "$dest/$dll" ]; then
			cp "/mingw64/bin/$dll" "$dest/$dll"
			copy_runtime_dlls "/mingw64/bin/$dll" "$dest"
		fi
	done
}

cd "$WORK_DIR"

echo "=== Cloning NXEngine-evo ==="
git clone --depth=1 "$NXENGINE_REPO" nxengine-evo
cd nxengine-evo

echo "=== Patching upstream for MinGW/GCC 16 compatibility ==="
sed -i 's#\.open(widen(\([^)]*\))#.open(widen(\1).c_str()#g' \
	src/map.cpp src/i18n/translate.cpp src/graphics/Font.cpp \
	src/sound/SoundManager.cpp src/tsc.cpp
sed -i 's#ifstream ifs(widen(\([^)]*\))#ifstream ifs(widen(\1).c_str()#g' \
	src/ResourceManager.cpp
sed -i '/add_executable(nx ${SOURCES})/a IF(MINGW)\n  set_property(TARGET nx APPEND_STRING PROPERTY LINK_FLAGS " -mwindows")\nENDIF()' \
	CMakeLists.txt

echo "=== Building NXEngine-evo (Windows x64) ==="
export SDL2DIR=/mingw64
export SDL2IMAGEDIR=/mingw64
export SDL2MIXERDIR=/mingw64
export CMAKE_PREFIX_PATH=/mingw64
cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DPORTABLE=ON \
	-DCMAKE_CXX_FLAGS="-DUNICODE -D_UNICODE" -Bbuild -H.
ninja -C build

echo "=== Staging Windows dist ==="
mkdir -p "$REPO_DIR/dist"
OUTPUT_DIR="$REPO_DIR/dist/NXEngine-Evo"
rm -rf "$OUTPUT_DIR"
mkdir "$OUTPUT_DIR"
cp build/nxengine-evo.exe "$OUTPUT_DIR/"
cp build/nxextract.exe "$OUTPUT_DIR/"
cp -r "$REPO_DIR/$DATA_DIR" "$OUTPUT_DIR/data"
copy_runtime_dlls build/nxengine-evo.exe "$OUTPUT_DIR"
copy_runtime_dlls build/nxextract.exe "$OUTPUT_DIR"

echo "=== Windows dist staged ==="
ls -la "$OUTPUT_DIR"
