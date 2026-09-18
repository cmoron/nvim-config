#!/usr/bin/env bash
# Build Neovim 0.12.5 on OL8 and qualify the existing Linux bundle with it.
# Usage: scripts/export-offline-el8.sh [existing-linux-x86_64-bundle.tar.gz]
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEED="${1:-$REPO_DIR/dist/nvim-config-offline-linux-x86_64.tar.gz}"
OL8='oraclelinux:8@sha256:21916d0f9527aa5d0b84034dcb3f6d2f01b59e633e31221b49855032ce41069a'
UBI9='registry.access.redhat.com/ubi9/ubi:9.6@sha256:dec374e05cc13ebbc0975c9f521f3db6942d27f8ccdf06b180160490eef8bdbc'
NAME=nvim-config-offline-el8-x86_64.tar.gz

if [ ! -f "$SEED" ]; then
    echo "Bundle Linux source absent : $SEED ; lancer export-offline-linux.sh d'abord." >&2
    exit 1
fi
docker info >/dev/null
mkdir -p "$REPO_DIR/dist"
STAGE=$(mktemp -d "$REPO_DIR/dist/.el8-build.XXXXXX")
cleanup() {
    local build_status=$?
    if [ "$build_status" -eq 0 ]; then
        rm -rf "$STAGE"
    else
        echo "Échec : artefacts conservés dans $STAGE" >&2
    fi
    return "$build_status"
}
trap cleanup EXIT
tar -xzf "$SEED" -C "$STAGE"
BUNDLE="$STAGE/nvim-config-offline"
if [ "$(cat "$BUNDLE/PLATFORM")" != 'Linux x86_64' ]; then
    echo 'Le bundle source doit cibler Linux x86_64.' >&2
    exit 1
fi
# This recipe reuses binaries, never silently packages an older configuration.
cp "$REPO_DIR/init.lua" "$BUNDLE/config/init.lua"
# Earlier Linux exports bootstrapped lazy itself at stable instead of its lock.
# Only that pure-Lua plugin may differ; native plugin versions must match.
LAZY_REVISION=$(python3 - "$REPO_DIR/lazy-lock.json" "$BUNDLE/config/lazy-lock.json" <<'PY'
import json, re, sys
current, seed = (json.load(open(path)) for path in sys.argv[1:])
revision = current.pop('lazy.nvim')['commit']
seed.pop('lazy.nvim')
assert current == seed, 'Le lock des plugins du bundle source a changé : reconstruire le bundle Linux.'
assert re.fullmatch(r'[0-9a-f]{40}', revision)
print(revision)
PY
)
curl --fail --location --retry 3 -o "$STAGE/lazy.tar.gz" \
    "https://github.com/folke/lazy.nvim/archive/$LAZY_REVISION.tar.gz"
rm -rf "$BUNDLE/plugins/lazy.nvim"
mkdir -p "$BUNDLE/plugins/lazy.nvim"
tar -xzf "$STAGE/lazy.tar.gz" -C "$BUNDLE/plugins/lazy.nvim" --strip-components=1
cp "$REPO_DIR/lazy-lock.json" "$BUNDLE/config/lazy-lock.json"
cp "$REPO_DIR/scripts/install-offline.sh" "$BUNDLE/install.sh"
chmod +x "$BUNDLE/install.sh"

docker build --platform linux/amd64 --progress plain \
    --build-arg "JOBS=${JOBS:-4}" \
    -f "$REPO_DIR/scripts/Dockerfile.neovim-ol8" \
    --output "type=local,dest=$STAGE/runtime" "$REPO_DIR/scripts"

# Upstream portable runtimes; no package manager or download on the receiver.
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nvim-config/downloads"
mkdir -p "$CACHE" "$BUNDLE/tools/"{jdk-25,node,pyright,bin}
fetch() {
    local name=$1 checksum=$2 url=$3
    if [ -f "$CACHE/$name" ] && [ "$(sha256sum "$CACHE/$name" | cut -d ' ' -f1)" = "$checksum" ]; then
        echo "Cache vérifié : $name"
    else
        curl --fail --location --retry 3 -o "$STAGE/$name" "$url"
        printf '%s  %s\n' "$checksum" "$STAGE/$name" | sha256sum -c -
        mv "$STAGE/$name" "$CACHE/$name"
    fi
    printf '%s  %s  %s\n' "$checksum" "$name" "$url" >> "$STAGE/tool-sources.txt"
}
fetch jdk25.tar.gz dbb698396d478e7fa2b1e50f4103324b2a99b90569ee27c33f2261f9215cf41e \
    'https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4.1%2B1/OpenJDK25U-jdk_x64_linux_hotspot_25.0.4.1_1.tar.gz'
fetch node24.tar.xz 55aa7153f9d88f28d765fcdad5ae6945b5c0f98a36881703817e4c450fa76742 \
    'https://nodejs.org/dist/v24.18.0/node-v24.18.0-linux-x64.tar.xz'
fetch pyright.tgz bd5c488fc20fa237a944279bf32cae2f986cf10d5d5d9e8705819859daeb2f4a \
    'https://registry.npmjs.org/pyright/-/pyright-1.1.411.tgz'
fetch ruff.tar.gz e56aa612121de356f37d05f3284cd806081fb72d5dbd4814b3810c5a23c562cc \
    'https://github.com/astral-sh/ruff/releases/download/0.16.8/ruff-x86_64-unknown-linux-musl.tar.gz'
fetch jdtls-1.61.0.tar.gz 338e7e73d61836651ba2453919a0d34fa763eb4e7c03342092309bffb8934c64 \
    'https://download.eclipse.org/jdtls/milestones/1.61.0/jdt-language-server-1.61.0-202609031315.tar.gz'
rm -rf "$BUNDLE/jdtls"
mkdir -p "$BUNDLE/jdtls"
tar -xzf "$CACHE/jdtls-1.61.0.tar.gz" -C "$BUNDLE/jdtls"
printf 'jdt-language-server-1.61.0-202609031315.tar.gz\n' > "$BUNDLE/jdtls/.installed-from"
tar -xzf "$CACHE/jdk25.tar.gz" -C "$BUNDLE/tools/jdk-25" --strip-components=1
tar -xJf "$CACHE/node24.tar.xz" -C "$BUNDLE/tools/node" --strip-components=1
tar -xzf "$CACHE/pyright.tgz" -C "$BUNDLE/tools/pyright" --strip-components=1
tar -xzf "$CACHE/ruff.tar.gz" -C "$STAGE"
cp "$STAGE/ruff-x86_64-unknown-linux-musl/ruff" "$BUNDLE/tools/bin/"
cat > "$BUNDLE/tools/bin/pyright-langserver" <<'PYRIGHT'
#!/usr/bin/env bash
set -euo pipefail
TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$TOOLS/node/bin/node" "$TOOLS/pyright/langserver.index.js" "$@"
PYRIGHT
chmod +x "$BUNDLE/tools/bin/pyright-langserver"

# Keep runtime data and licences; omit development tools and test fixtures.
find "$BUNDLE/plugins" -mindepth 2 -maxdepth 2 -type d \
    \( -name .github -o -name tests -o -name test \) -prune -exec rm -rf {} +
rm -rf "$BUNDLE/tools/node/include" "$BUNDLE/tools/node/lib" "$BUNDLE/tools/node/share" \
    "$BUNDLE/tools/node/bin/npm" "$BUNDLE/tools/node/bin/npx" "$BUNDLE/tools/node/bin/corepack"
rm -f "$BUNDLE/tools/pyright/dist/"*.map
find "$BUNDLE/jdtls" -mindepth 1 -maxdepth 1 -type d -name 'config_*' \
    ! -name config_linux -exec rm -rf {} +

rm -f "$BUNDLE"/nvim-linux-*.tar.gz
cp "$STAGE/runtime/nvim-linux-x86_64.tar.gz" "$BUNDLE/"
mkdir -p "$BUNDLE/build-info"
cp "$STAGE/runtime/"*.txt "$BUNDLE/build-info/"
cp -R "$STAGE/runtime/licenses" "$BUNDLE/"
cp "$STAGE/tool-sources.txt" "$BUNDLE/build-info/"
cp "$REPO_DIR/scripts/Dockerfile.neovim-ol8" "$BUNDLE/build-info/"
cp "$REPO_DIR/scripts/export-offline-el8.sh" "$BUNDLE/build-info/"
bash "$REPO_DIR/scripts/collect-offline-notices.sh" "$BUNDLE" "$CACHE"
cp "$REPO_DIR/scripts/collect-offline-notices.sh" "$BUNDLE/build-info/"
mkdir -p "$BUNDLE/checks"
cp "$REPO_DIR/scripts/"check-{runtime,lsp}.lua "$BUNDLE/checks/"
cp "$REPO_DIR/docs/offline-el8.md" "$BUNDLE/README.md"
printf 'Voir README.md pour les outils Java/Python inclus et les dépendances de projet à fournir.\n' > "$BUNDLE/DEPENDENCIES.md"
{
    printf 'Neovim: v0.12.5\nTarget: Linux x86_64, glibc 2.28\nBuilder: %s\n' "$OL8"
    printf 'Source: https://github.com/neovim/neovim/archive/refs/tags/v0.12.5.tar.gz\n'
    printf 'Source SHA256: a810c95332317bd0017e1ca07e376a8472c79075cbed00fa3737d190a8a0a45a\n'
    printf 'Seed SHA256: %s\n' "$(sha256sum "$SEED" | cut -d ' ' -f1)"
    printf 'lazy.nvim: %s; source SHA256: %s\n' "$LAZY_REVISION" "$(sha256sum "$STAGE/lazy.tar.gz" | cut -d ' ' -f1)"
    printf 'Repository HEAD: %s (configuration checksums below are authoritative)\n' "$(git -C "$REPO_DIR" rev-parse HEAD)"
    printf 'Parsers and blink reused from seed; qualified on OL8 and UBI9.\n'
    printf 'Acceptance: %s\nAcceptance: %s\n' "$OL8" "$UBI9"
    cd "$BUNDLE"
    sha256sum config/init.lua config/lazy-lock.json install.sh checks/*.lua nvim-linux-x86_64.tar.gz
} > "$BUNDLE/build-info/manifest.txt"
tar -czf "$STAGE/$NAME" -C "$STAGE" nvim-config-offline

# Publish only after the exact archive passes both receiving environments.
bash "$REPO_DIR/scripts/test-offline-linux.sh" "$STAGE/$NAME" "$OL8"
bash "$REPO_DIR/scripts/test-offline-linux.sh" "$STAGE/$NAME" "$UBI9"
mv "$STAGE/$NAME" "$REPO_DIR/dist/$NAME"
(cd "$REPO_DIR/dist" && sha256sum "$NAME" > "$NAME.sha256")
echo "Bundle EL8 validé : $REPO_DIR/dist/$NAME"
