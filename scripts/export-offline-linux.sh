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
#   ./scripts/export-offline-linux.sh            # x86_64, nvim stable
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

NVIM_VERSION="${NVIM_VERSION:-stable}"
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
    "$IMAGE" bash -euo pipefail -c '
echo "→ dépendances système"
# gcc et tree-sitter compilent les parsers ; unzip extrait les jars des
# extensions VS Code ; le JDK conditionne l installation de jdtls.
dnf -y -q install git curl gcc unzip tar findutils ripgrep nodejs npm \
    java-21-openjdk-devel python3 >/dev/null

echo "→ neovim $NVIM_VERSION"
curl -fsSL -o /tmp/nvim-linux-$NVIM_ARCH.tar.gz \
    "https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/nvim-linux-$NVIM_ARCH.tar.gz"
mkdir -p /opt/nvim
tar -xzf /tmp/nvim-linux-$NVIM_ARCH.tar.gz -C /opt/nvim --strip-components=1
export PATH="/opt/nvim/bin:$PATH"
nvim --version | head -1

echo "→ tree-sitter CLI"
npm install -g --silent tree-sitter-cli >/dev/null

# Copie car install.sh pose un symlink vers le dépôt et export-offline.sh
# écrit dans dist/ : les deux échouent sur un montage read-only.
cp -R /repo /work
cd /work
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
# install.sh sort en 1 si un composant optionnel manque : un LSP Go, un
# formatter Rust, le marketplace en 503. Sans gravité pour un bundle, dont les
# vraies conditions de succès sont vérifiées explicitement plus bas.
./scripts/install.sh || echo "  (install.sh signale des manques — vérification ciblée plus bas)"

# install.sh charge les plugins mais la compilation des parsers est
# asynchrone : nvim rendrait la main avant la fin. On rejoue install() sur la
# liste exposée par init.lua, cette fois en attendant.
echo "→ parsers Treesitter (compilation)"
nvim --headless -c "lua require(\"nvim-treesitter\").install(vim.g.ts_parsers):wait(1800000)" +qa
PARSERS=$(ls -1 "$HOME/.local/share/nvim/site/parser"/*.so 2>/dev/null | wc -l)
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

cp dist/nvim-config-offline.tar.gz /out/nvim-config-offline-linux-$NVIM_ARCH.tar.gz
'

ARCHIVE="$REPO_DIR/dist/nvim-config-offline-linux-$NVIM_ARCH.tar.gz"
echo ""
echo "Bundle prêt : ${ARCHIVE#"$REPO_DIR"/} ($(du -h "$ARCHIVE" | cut -f1))"
echo ""
echo "Sur la machine cible :"
echo "  tar -xzf $(basename "$ARCHIVE")"
echo "  cd nvim-config-offline && ./install.sh"
