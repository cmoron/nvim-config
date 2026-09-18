#!/usr/bin/env bash
# =============================================================================
# export-offline-linux.sh — bundle offline pour une cible Linux, depuis
# n'importe quelle machine dotée de Docker.
#
# export-offline.sh copie les binaires de la machine courante : lancé sur un
# Mac, il produit des parsers Mach-O et un fuzzy blink en .dylib, inutilisables
# sur Linux. Ce wrapper rejoue le même export dans un conteneur de la bonne
# plateforme, seul endroit où ces binaires naissent avec le bon format.
#
# Le conteneur a le réseau (github.com, eclipse.org, marketplace VS Code) ;
# la cible, elle, n'en a pas besoin. Le bundle produit embarque le runtime
# Neovim, donc il ne dépend pas des dépôts de la machine d'arrivée.
#
#   ./scripts/export-offline-linux.sh            # x86_64, nvim 0.12.5
#   ARCH=arm64 ./scripts/export-offline-linux.sh # cible aarch64
#   NVIM_VERSION=v0.12.4 ./scripts/export-offline-linux.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# ARCH nomme la cible en vocabulaire Docker ; NVIM_ARCH la même chose en
# vocabulaire release Neovim. Les deux diffèrent, d'où la table.
ARCH="${ARCH:-amd64}"
case "$ARCH" in
    amd64|x86_64) DOCKER_PLATFORM="linux/amd64"; NVIM_ARCH="x86_64" ;;
    arm64|aarch64) DOCKER_PLATFORM="linux/arm64"; NVIM_ARCH="arm64" ;;
    *) echo "ARCH inconnu: $ARCH (attendu amd64 ou arm64)" >&2; exit 1 ;;
esac

NVIM_VERSION="${NVIM_VERSION:-v0.12.5}"
TREE_SITTER_VERSION="${TREE_SITTER_VERSION:-v0.26.1}"
BUN_VERSION="${BUN_VERSION:-bun-v1.3.10}"
IMAGE="${IMAGE:-fedora:43}"

if ! command -v docker &>/dev/null; then
    echo "docker introuvable — requis pour construire un bundle Linux." >&2
    exit 1
fi

echo "Construction du bundle offline"
echo "  plateforme : $DOCKER_PLATFORM  (image $IMAGE)"
echo "  neovim     : $NVIM_VERSION (nvim-linux-$NVIM_ARCH)"
if [ "$(uname -m)" != "$NVIM_ARCH" ]; then
    echo "  note       : émulation qemu — compter ~10-20 min pour les parsers"
fi
echo ""

mkdir -p "$REPO_DIR/dist"

# java-debug et java-test ne viennent que du marketplace VS Code, qui renvoie
# des 503 sporadiques. Ce sont des jars, donc indépendants de la plateforme :
# ceux de la machine hôte font l'affaire et évitent un aller-retour réseau au
# milieu d'un build long. Tableau expansé à la mode bash 3.2 (celui d'Apple),
# qui refuse "${arr[@]}" sur un tableau vide sous set -u.
JAR_MOUNTS=()
for component in java-debug java-test; do
    if [ -d "$HOME/.local/share/$component" ]; then
        JAR_MOUNTS+=(-v "$HOME/.local/share/$component:/seed/$component:ro")
        echo "  réutilise  : ~/.local/share/$component (jars portables)"
    fi
done
[ ${#JAR_MOUNTS[@]} -gt 0 ] && echo ""

# Le dépôt est monté en lecture seule : install.sh y crée un symlink et
# export-offline.sh y écrit dist/, donc le conteneur travaille sur une copie
# et ne rend que l'archive finale.
docker run --rm --platform "$DOCKER_PLATFORM" \
    -v "$REPO_DIR:/repo:ro" \
    -v "$REPO_DIR/dist:/out" \
    ${JAR_MOUNTS[@]+"${JAR_MOUNTS[@]}"} \
    -e NVIM_VERSION="$NVIM_VERSION" \
    -e NVIM_ARCH="$NVIM_ARCH" \
    -e TREE_SITTER_VERSION="$TREE_SITTER_VERSION" \
    -e BUN_VERSION="$BUN_VERSION" \
    "$IMAGE" bash -euo pipefail -c '
echo "→ dépendances système"
# gcc et tree-sitter compilent les parsers ; unzip extrait les jars des
# extensions VS Code ; le JDK conditionne l installation de jdtls.
dnf -y -q install git curl gcc unzip tar gzip findutils ripgrep nodejs \
    java-25-openjdk-devel python3 >/dev/null

echo "→ neovim $NVIM_VERSION"
curl -fsSL -o "/tmp/nvim-linux-$NVIM_ARCH.tar.gz" \
    "https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/nvim-linux-$NVIM_ARCH.tar.gz"
mkdir -p /opt/nvim
tar -xzf "/tmp/nvim-linux-$NVIM_ARCH.tar.gz" -C /opt/nvim --strip-components=1
export PATH="/opt/nvim/bin:$PATH"
nvim --version | head -1

echo "→ tree-sitter CLI"
TS_ARCH=$NVIM_ARCH
[ "$TS_ARCH" != x86_64 ] || TS_ARCH=x64
curl -fsSL -o /tmp/tree-sitter.gz \
    "https://github.com/tree-sitter/tree-sitter/releases/download/$TREE_SITTER_VERSION/tree-sitter-linux-$TS_ARCH.gz"
gzip -dc /tmp/tree-sitter.gz > /usr/local/bin/tree-sitter
chmod +x /usr/local/bin/tree-sitter
tree-sitter --version

echo "→ Bun (installation des outils JS)"
curl -fsSL -o /tmp/install-bun.sh https://bun.sh/install
bash /tmp/install-bun.sh "$BUN_VERSION"
export PATH="$HOME/.bun/bin:$PATH"

# Copie car install.sh pose un symlink vers le dépôt et export-offline.sh
# écrit dans dist/ : les deux échouent sur un montage read-only.
cp -R /repo /work
cd /work || exit 1
rm -rf dist

# install_vscode_jars saute le téléchargement quand les jars sont déjà là :
# pré-remplir revient à court-circuiter le marketplace.
for component in java-debug java-test; do
    if [ -d "/seed/$component" ]; then
        mkdir -p "$HOME/.local/share/$component"
        cp /seed/$component/*.jar "$HOME/.local/share/$component/"
    fi
done

echo "→ plugins, LSP et chaîne Java"
# lazy cannot restore its own bootstrap revision through :Lazy restore.
LAZY_REVISION=$(python3 -c "import json; print(json.load(open(\"lazy-lock.json\"))[\"lazy.nvim\"][\"commit\"])")
mkdir -p "$HOME/.local/share/nvim/lazy"
git clone --filter=blob:none https://github.com/folke/lazy.nvim.git "$HOME/.local/share/nvim/lazy/lazy.nvim"
git -C "$HOME/.local/share/nvim/lazy/lazy.nvim" checkout --detach "$LAZY_REVISION"
# Les outils optionnels absents donnent des avertissements, pas un exit 1.
# Un vrai échec (plugins ou téléchargement Java) doit arrêter le build.
./scripts/install.sh

# En headless, init.lua ne lance ni install() ni TSUpdate automatiquement.
# Compiler une seule fois, attendre, puis charger chaque parser avant export.
echo "→ parsers Treesitter (compilation)"
nvim --headless -c "lua require(\"nvim-treesitter\").install(vim.g.ts_parsers):wait(1800000)" +qa
# Un nouveau processus découvre aussi les dossiers parser/queries créés au build.
nvim --headless -c "luafile scripts/check-runtime.lua"
PARSERS=$(find "$HOME/.local/share/nvim/site/parser" -maxdepth 1 -type f -name "*.so" | wc -l)
echo "  $PARSERS parsers compilés"

# Conditions de succès du bundle, par opposition aux manques tolérables.
echo "→ vérification"
FATAL=0
if [ "$PARSERS" -eq 0 ]; then
    echo "  ERREUR: aucun parser compilé" >&2; FATAL=1
fi
if [ ! -d "$HOME/.local/share/nvim/lazy/lazy.nvim" ]; then
    echo "  ERREUR: plugins absents" >&2; FATAL=1
fi
if ! ls "$HOME/.local/share/nvim/lazy"/blink.cmp/target/release/libblink_cmp_fuzzy.* >/dev/null 2>&1; then
    echo "  ATTENTION: binaire fuzzy blink.cmp absent — repli Lua sur la cible"
fi
for component in jdtls java-debug java-test; do
    [ -d "$HOME/.local/share/$component" ] \
        || echo "  ATTENTION: $component manquant — support Java partiel dans le bundle"
done
[ "$FATAL" -eq 0 ] || { echo "Bundle inutilisable, abandon." >&2; exit 1; }

echo "→ export"
NVIM_TARBALL=/tmp/nvim-linux-$NVIM_ARCH.tar.gz ./scripts/export-offline.sh

cp dist/nvim-config-offline.tar.gz "/out/nvim-config-offline-linux-$NVIM_ARCH.tar.gz"
'

ARCHIVE="$REPO_DIR/dist/nvim-config-offline-linux-$NVIM_ARCH.tar.gz"
echo ""
echo "Bundle prêt : ${ARCHIVE#"$REPO_DIR"/} ($(du -h "$ARCHIVE" | cut -f1))"
echo ""
echo "Sur la machine cible :"
echo "  tar -xzf $(basename "$ARCHIVE")"
echo "  cd nvim-config-offline && ./install.sh"
