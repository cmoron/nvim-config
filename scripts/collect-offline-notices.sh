#!/usr/bin/env bash
# Collect redistribution notices for the source artifacts embedded in an EL8 bundle.
# Usage: scripts/collect-offline-notices.sh BUNDLE CACHE
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 BUNDLE CACHE" >&2
    exit 2
fi

BUNDLE=$1
CACHE=$2
PARSERS_DIR="$BUNDLE/treesitter-parsers"
PARSERS_LUA="$BUNDLE/plugins/nvim-treesitter/lua/nvim-treesitter/parsers.lua"
LICENSES="$BUNDLE/licenses"
MANIFEST="$BUNDLE/build-info/source-notices.txt"

for path in "$BUNDLE" "$PARSERS_DIR" "$PARSERS_LUA"; do
    if [ ! -e "$path" ]; then
        echo "Entrée absente pour les notices : $path" >&2
        exit 1
    fi
done

mkdir -p "$CACHE/notices" "$BUNDLE/build-info"
mkdir -p "$LICENSES"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fetch_source() {
    local cache_name=$1 url=$2
    local archive="$CACHE/notices/$cache_name"
    if [ ! -s "$archive" ]; then
        local partial
        partial=$(mktemp "$CACHE/notices/.${cache_name}.XXXXXX")
        curl --fail --location --retry 3 --output "$partial" "$url"
        mv "$partial" "$archive"
    fi
    tar -tzf "$archive" >/dev/null
    printf '%s\n' "$archive"
}

extract_notices() {
    local archive=$1 destination=$2
    python3 - "$archive" "$destination" <<'PY'
import shutil
import sys
import tarfile
from pathlib import Path

archive, destination = map(Path, sys.argv[1:])
notice_prefixes = ("license", "copying", "notice", "copyright", "third-party")
with tarfile.open(archive, "r:*") as tar:
    files = [member for member in tar.getmembers() if member.isfile()]
    roots = {member.name.split("/", 1)[0] for member in files if "/" in member.name}
    if len(roots) != 1:
        raise SystemExit(f"archive source ambigu: {archive}")
    root = roots.pop() + "/"
    selected = []
    for member in files:
        relative = member.name.removeprefix(root)
        if "/" not in relative and relative.lower().startswith(notice_prefixes):
            selected.append(member)
    licenses = [member for member in selected if Path(member.name).name.lower().startswith(("license", "copying"))]
    if not licenses:
        raise SystemExit(f"licence absente dans {archive}")
    destination.mkdir(parents=True, exist_ok=True)
    for member in selected:
        target = destination / Path(member.name).name
        if target.exists():
            target = destination / member.name.removeprefix(root).replace("/", "__")
        with tar.extractfile(member) as source, target.open("wb") as output:
            shutil.copyfileobj(source, output)
PY
}

record_source() {
    local label=$1 version=$2 source_url=$3 archive=$4 notices=$5
    {
        printf '%s\n' "[$label]"
        printf 'version: %s\n' "$version"
        printf 'source: %s\n' "$source_url"
        printf 'sha256: %s\n' "$(sha256sum "$archive" | cut -d ' ' -f1)"
        printf 'notices: licenses/%s\n\n' "$notices"
    } >> "$MANIFEST"
}

collect_component() {
    local label=$1 version=$2 source_url=$3 cache_name=$4 destination=$5
    local archive
    archive=$(fetch_source "$cache_name" "$source_url")
    extract_notices "$archive" "$LICENSES/$destination"
    record_source "$label" "$version" "$source_url" "$archive" "$destination"
}

: > "$MANIFEST"
printf '%s\n\n' '# Source archives and copied notices for redistributed offline components.' >> "$MANIFEST"

collect_component ruff 0.16.8 \
    'https://github.com/astral-sh/ruff/archive/refs/tags/0.16.8.tar.gz' \
    ruff-0.16.8.tar.gz ruff
collect_component jdtls 1.61.0 \
    'https://github.com/eclipse-jdtls/eclipse.jdt.ls/archive/refs/tags/v1.61.0.tar.gz' \
    jdtls-v1.61.0.tar.gz jdtls
collect_component 'java-debug associated source' 'tag 0.53.2 for com.microsoft.java.debug.plugin-0.53.2.jar' \
    'https://github.com/microsoft/java-debug/archive/refs/tags/0.53.2.tar.gz' \
    java-debug-0.53.2.tar.gz java-debug
collect_component 'java-test associated source' 'tag 0.43.1 for com.microsoft.java.test.plugin-0.43.1.jar' \
    'https://github.com/microsoft/vscode-java-test/archive/refs/tags/0.43.1.tar.gz' \
    java-test-0.43.1.tar.gz java-test

python3 - "$PARSERS_LUA" "$PARSERS_DIR" > "$TMP/grammars.tsv" <<'PY'
import re
import sys
from pathlib import Path

registry, parsers_dir = map(Path, sys.argv[1:])
text = registry.read_text(encoding="utf-8")
entries = {}
for match in re.finditer(
    r"^  ([A-Za-z0-9_]+)\s*=\s*\{\n    install_info\s*=\s*\{(?P<info>.*?)^    \},",
    text,
    re.MULTILINE | re.DOTALL,
):
    info = match.group("info")
    url = re.search(r"^      url\s*=\s*'([^']+)'", info, re.MULTILINE)
    revision = re.search(r"^      revision\s*=\s*'([^']+)'", info, re.MULTILINE)
    if url and revision:
        entries[match.group(1)] = (url.group(1), revision.group(1))

parsers = sorted(path.stem for path in parsers_dir.glob("*.so"))
if not parsers:
    raise SystemExit("aucun parser Tree-sitter dans le bundle")
for parser in parsers:
    try:
        url, revision = entries[parser]
    except KeyError:
        raise SystemExit(f"provenance absente pour le parser {parser}") from None
    if not re.fullmatch(r"https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", url):
        raise SystemExit(f"source Tree-sitter non prise en charge pour {parser}: {url}")
    if not (
        re.fullmatch(r"[0-9a-f]{40}", revision)
        or re.fullmatch(r"v?\d+(?:\.\d+)+(?:[-._+A-Za-z0-9]+)?", revision)
    ):
        raise SystemExit(f"révision Tree-sitter invalide pour {parser}: {revision}")
    print(f"{parser}\t{url}\t{revision}")
PY

parser_count=0
while IFS=$'\t' read -r parser source_url revision; do
    repo=${source_url#https://github.com/}
    cache_name="tree-sitter-${repo//\//-}-${revision}.tar.gz"
    archive=$(fetch_source "$cache_name" "$source_url/archive/$revision.tar.gz")
    extract_notices "$archive" "$LICENSES/tree-sitter/$parser"
    record_source "tree-sitter-$parser" "$revision" "$source_url/archive/$revision.tar.gz" "$archive" "tree-sitter/$parser"
    parser_count=$((parser_count + 1))
done < "$TMP/grammars.tsv"

if [ "$parser_count" -eq 0 ]; then
    echo 'Aucun parser Tree-sitter traité.' >&2
    exit 1
fi

printf 'Notices collectées : %s composants Tree-sitter, 4 composants Java/Python.\n' "$parser_count"
