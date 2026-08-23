#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.0.0}"

REPO_DIR="$(pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Languages to build. The Traditional Chinese variant is created from lang_chinese.
LANGUAGES=(
	chinese
	chinese_tr
	japanese
	korean
	russian
	arabic
	german
	italian
	spanish
	french
	polish
)

# Map each language to the font file it should use.
declare -A LANG_FONT_FILE=(
	[chinese]="ark-pixel-12px-monospaced-zh_cn.ttf"
	[chinese_tr]="ark-pixel-12px-monospaced-zh_tw.ttf"
	[japanese]="ark-pixel-12px-monospaced-ja.ttf"
	# Ark Pixel 'ko' variant does not include Hangul syllables, so use the bundled NanumGothic.
	[korean]="NanumGothic.ttf"
	[german]="ark-pixel-12px-monospaced-latin.ttf"
	[italian]="ark-pixel-12px-monospaced-latin.ttf"
	[spanish]="ark-pixel-12px-monospaced-latin.ttf"
	[french]="ark-pixel-12px-monospaced-latin.ttf"
	[polish]="ark-pixel-12px-monospaced-latin.ttf"
	[russian]="ark-pixel-12px-monospaced-latin.ttf"
	[arabic]="unifont-10.0.06.ttf"
)

# Display name for the Traditional Chinese glyph variant.
declare -A CHINESE_VARIANT_NAME=(
	[tr]="繁体中文"
)

cd "$WORK_DIR"

echo "=== Cloning translations ==="
git clone --depth=1 "$TRANSLATIONS_REPO" translations
cd translations/local

echo "=== Cloning language packs ==="
for lang in chinese japanese korean arabic german italian spanish french polish russian; do
	echo "Cloning lang_$lang..."
	git clone --depth=1 "https://github.com/nxengine/lang_${lang}" "lang_${lang}"
done

echo "=== Creating Traditional Chinese glyph variant ==="
for variant in tr; do
	target="lang_chinese_${variant}"
	cp -r lang_chinese "$target"
	# Give the variant a distinct language id and display name.
	sed -i "1s/\"chinese\"/\"chinese_${variant}\"/" "$target/system.json"
	sed -i "1s/\"中文\"/\"${CHINESE_VARIANT_NAME[$variant]}\"/" "$target/system.json"
done

echo "=== Preparing fonts ==="
mkdir -p assets

# Copy all Ark Pixel fonts from the artifact.
for f in "$REPO_DIR/font"/ark-pixel-12px-monospaced-*.ttf; do
	cp "$f" "assets/$(basename "$f")"
done

# Arabic still needs Unifont.
curl -sL -o assets/unifont-10.0.06.ttf \
	"https://raw.githubusercontent.com/nxengine/nx-fontgen/master/assets/unifont-10.0.06.ttf"

# Korean uses the font bundled in its own repo (Ark Pixel 'ko' lacks Hangul).
cp "lang_korean/assets/NanumGothic.ttf" "assets/NanumGothic.ttf"

echo "=== Patching language display names ==="
# The in-game language menu shows the directory name, then translates it through
# the current language's system.json. Add every language's native name to each
# system.json so the menu shows proper names (简体中文 / 繁体中文 / ...).
# The suffix is rendered with the CURRENT language's font, so the characters in
# those names must also be present in the generated font textures. Append the
# missing glyph codepoints to the metadata of CJK-capable fonts.
python3 - <<'PYEOF'
import json, os

names = {
    "english": "English",
    "chinese": "简体中文",
    "chinese_tr": "繁体中文",
    "japanese": "日本語",
    "korean": "한국어",
    "russian": "Русский",
    "arabic": "العربية",
    "german": "Deutsch",
    "italian": "Italiano",
    "spanish": "Español",
    "french": "Français",
    "polish": "Polski",
}

for entry in os.listdir("."):
    if not entry.startswith("lang_"):
        continue
    path = os.path.join(entry, "system.json")
    if not os.path.isfile(path):
        continue
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    data.update(names)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("patched", entry)

# Fonts used by these languages cover CJK / Latin / Kana, so the display-name
# characters can be rendered there. Fonts for Latin-only languages are skipped.
cjk_langs = {"chinese", "chinese_tr", "japanese", "korean", "arabic"}

def font_supports(cp):
    # Basic Latin + Latin-1/Latin Extended, CJK punctuation, kana, CJK ideographs, fullwidth forms
    if 0x20 <= cp <= 0x24F:
        return True
    if 0x3000 <= cp <= 0x303F:
        return True
    if 0x3040 <= cp <= 0x30FF:
        return True
    if 0x4E00 <= cp <= 0x9FFF:
        return True
    if 0xFF00 <= cp <= 0xFFEF:
        return True
    return False

extra = sorted({c for ch in names.values() for c in (ord(x) for x in ch) if font_supports(c)})

for entry in os.listdir("."):
    if not entry.startswith("lang_"):
        continue
    lang = entry[len("lang_"):]
    if lang not in cjk_langs:
        continue
    meta = os.path.join(entry, "metadata")
    if not os.path.isfile(meta):
        continue
    with open(meta, encoding="utf-8") as f:
        lines = f.read().splitlines()
    if not lines:
        continue
    parts = lines[0].split()
    if len(parts) < 7:
        continue
    chars_field = parts[6]
    existing = set()
    for token in chars_field.split(","):
        if "-" in token:
            a, b = token.split("-", 1)
            try:
                existing.update(range(int(a), int(b) + 1))
            except ValueError:
                pass
        else:
            try:
                existing.add(int(token))
            except ValueError:
                pass
    to_add = [c for c in extra if c not in existing]
    if to_add:
        parts[6] = chars_field + "," + ",".join(str(c) for c in to_add)
        lines[0] = " ".join(parts)
        with open(meta, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        print("glyphs added", entry, len(to_add))
PYEOF

echo "=== Patching font metadata ==="
for lang in "${LANGUAGES[@]}"; do
	font_file="${LANG_FONT_FILE[$lang]}"
	# Replace the first token (font path) in the metadata file.
	sed -i "1s|^[^ ]*|assets/${font_file}|" "lang_${lang}/metadata"
	echo "lang_$lang -> $font_file"
done

echo "=== Building localized data ==="
cd "$WORK_DIR/translations"
bash build-local.sh

echo "=== Cloning NXEngine-evo ==="
cd "$WORK_DIR"
git clone --depth=1 "$NXENGINE_REPO" nxengine-evo
cd nxengine-evo

echo "=== Building nxextract ==="
cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DPORTABLE=ON -Bbuild -H.
ninja -C build extract

echo "=== Downloading Cave Story ==="
cd "$WORK_DIR"
wget -q "$CAVESTORY_URL" -O cavestoryen.zip
unzip -q cavestoryen.zip

echo "=== Merging game data ==="
cd nxengine-evo
cp -r "$WORK_DIR/CaveStory/data/." data/
cp "$WORK_DIR/CaveStory/Doukutsu.exe" .

echo "=== Running nxextract ==="
./build/nxextract

echo "=== Adding language packs ==="
mkdir -p data/lang
cp -r "$WORK_DIR/translations/local/data/lang/." data/lang/

echo "=== Packaging data ==="
mkdir -p "$REPO_DIR/dist"
rm -rf "$REPO_DIR/dist/data"
cp -r data "$REPO_DIR/dist/data"

echo "=== Data ready ==="
ls -la "$REPO_DIR/dist/data"
ls -la "$REPO_DIR/dist/data/lang"
