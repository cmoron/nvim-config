#!/usr/bin/env bash
# ============================================================================
# Script d'installation de la configuration Neovim (offline)
# ============================================================================

set -euo pipefail

# Les chemins du bundle sont relatifs au script, jamais au dossier appelant.
cd "$(dirname "${BASH_SOURCE[0]}")"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Installation Neovim (offline)${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Le bundle transporte des binaires natifs (parsers Treesitter, fuzzy blink,
# runtime nvim). Les poser sur une autre plateforme produit des pannes
# obscures à l'usage : mieux vaut refuser ici.
if [ -f PLATFORM ]; then
    BUNDLE_PLATFORM=$(cat PLATFORM)
    HOST_PLATFORM="$(uname -s) $(uname -m)"
    if [ "$BUNDLE_PLATFORM" != "$HOST_PLATFORM" ]; then
        echo -e "${RED}Erreur: bundle construit pour '$BUNDLE_PLATFORM', machine '$HOST_PLATFORM'${NC}"
        echo -e "Régénérez le bundle sur la bonne plateforme (scripts/export-offline-linux.sh)."
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Plateforme: $HOST_PLATFORM"
fi

# Chemins
NVIM_CONFIG_DIR="$HOME/.config/nvim"
NVIM_DATA_DIR="$HOME/.local/share/nvim"
LAZY_DIR="$NVIM_DATA_DIR/lazy"

nvim_major_minor() {
    nvim --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -1
}

nvim_supported() {
    local version
    version=$(nvim_major_minor) || return 1
    [[ "$version" =~ ^[0-9]+\.[0-9]+$ ]] || return 1
    (( ${version%%.*} > 0 || ${version##*.} >= 12 ))
}

BACKUP_SUFFIX=".bak-$(date +%Y%m%d-%H%M%S)-$$"
backup() {
    if [ -e "$1" ] || [ -L "$1" ]; then
        mv "$1" "$1$BACKUP_SUFFIX"
        echo -e "${BLUE}→${NC} Sauvegarde : $1$BACKUP_SUFFIX"
    fi
}

# Runtime Neovim embarqué : extrait sous ~/.local/share, exposé via
# ~/.local/bin. Aucune écriture hors du HOME, donc utilisable sans droits root,
# y compris sur un système à racine immuable.
NVIM_ARCHIVE=""
for candidate in nvim-linux-*.tar.gz; do
    if [ -f "$candidate" ]; then NVIM_ARCHIVE="$candidate"; break; fi
done
if [ -d tools ] && [ -z "$NVIM_ARCHIVE" ]; then
    echo 'Erreur : la toolchain exige une archive du runtime Neovim.' >&2
    exit 1
fi
if [ -n "$NVIM_ARCHIVE" ] && { [ -d tools ] || ! nvim_supported; }; then
    echo -e "${BLUE}→${NC} Installation du runtime Neovim embarqué ($NVIM_ARCHIVE)..."
    backup "$HOME/.local/share/neovim"
    backup "$HOME/.local/bin/nvim"
    mkdir -p "$HOME/.local/share/neovim" "$HOME/.local/bin"
    # --strip-components : l'archive officielle a un dossier racine versionné.
    tar -xzf "$NVIM_ARCHIVE" -C "$HOME/.local/share/neovim" --strip-components=1
    ln -sf "$HOME/.local/share/neovim/bin/nvim" "$HOME/.local/bin/nvim"
    echo -e "${GREEN}✓${NC} Neovim installé dans ~/.local/share/neovim"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) echo -e "${YELLOW}⚠${NC} Ajoutez ~/.local/bin à votre PATH" ;;
    esac
    export PATH="$HOME/.local/bin:$PATH"
fi

if ! command -v nvim &> /dev/null; then
    echo -e "${RED}Erreur: Neovim n'est pas installé${NC}"
    echo -e "Installez Neovim >= 0.12 avant de continuer"
    exit 1
fi

NVIM_VERSION=$(nvim_major_minor || echo "0.0")
echo -e "${BLUE}→${NC} Neovim version: $NVIM_VERSION"
if ! nvim_supported; then
    echo -e "${RED}Erreur:${NC} Neovim >= 0.12 fonctionnel requis (runtime et bibliothèques système)."
    exit 1
fi

# Déplacer plutôt qu'écrire à travers un symlink vers un dépôt personnel.
# Les plugins et jars sont remplacés, jamais fusionnés avec une autre version.
backup "$NVIM_CONFIG_DIR"
backup "$NVIM_DATA_DIR"

# Keep redistribution notices even if the unpacked bundle is later removed.
if [ -d licenses ]; then
    mkdir -p "$NVIM_DATA_DIR/licenses"
    cp -R licenses/. "$NVIM_DATA_DIR/licenses/"
    if [ -f build-info/source-notices.txt ]; then
        cp build-info/source-notices.txt "$NVIM_DATA_DIR/licenses/"
    fi
fi

# Installation
echo -e "\n${GREEN}[1/5]${NC} Installation de la configuration..."
mkdir -p "$NVIM_CONFIG_DIR"
cp config/init.lua "$NVIM_CONFIG_DIR/"
if [ -f "config/lazy-lock.json" ]; then
    cp config/lazy-lock.json "$NVIM_CONFIG_DIR/"
fi
echo -e "${GREEN}✓${NC} Configuration copiée"

echo -e "\n${GREEN}[2/5]${NC} Installation des plugins (dont lazy.nvim)..."
mkdir -p "$LAZY_DIR"
for plugin_dir in plugins/*; do
    if [ -d "$plugin_dir" ]; then
        echo -e "${BLUE}→${NC} $(basename "$plugin_dir")"
        # cp -r fusionne au lieu de remplacer : sans ce rm, les fichiers d'un
        # déploiement précédent survivent. blink.cmp y laissait son `version`,
        # qui lui fait croire à un binaire téléchargé, désactive le chemin
        # « binaire posé à la main » et redonne « No fuzzy matching library ».
        rm -rf "${LAZY_DIR:?}/$(basename "$plugin_dir")"
        cp -r "$plugin_dir" "$LAZY_DIR/"
    fi
done
echo -e "${GREEN}✓${NC} Plugins installés"

echo -e "\n${GREEN}[3/5]${NC} Installation des parsers Treesitter (branche main)..."
if [ -d "treesitter-parsers" ]; then
    SITE_PARSER_DIR="$NVIM_DATA_DIR/site/parser"
    mkdir -p "$SITE_PARSER_DIR"
    cp treesitter-parsers/*.so "$SITE_PARSER_DIR/"
    PARSER_COUNT=$(find "$SITE_PARSER_DIR" -name '*.so' -type f | wc -l | tr -d ' ')
    echo -e "${GREEN}✓${NC} $PARSER_COUNT parsers Treesitter installés (offline)"
else
    echo -e "${YELLOW}⚠${NC} Pas de parsers inclus. Ils seront compilés au premier lancement"
    echo -e "  (nécessite le CLI tree-sitter et un compilateur C)."
fi

# nvim-treesitter (branche main) lit ses queries dans site/queries/<lang>, des
# liens vers runtime/queries/<lang> du plugin. C'est install() qui les pose,
# mais il télécharge le parser d'abord : hors ligne il échoue avant d'y arriver.
# Sans ces liens le parser s'attache sans aucune query — vim.treesitter.start()
# réussit, et le tampon reste sans la moindre couleur, dans tous les langages.
TS_QUERY_SRC="$LAZY_DIR/nvim-treesitter/runtime/queries"
if [ -d "$TS_QUERY_SRC" ]; then
    SITE_QUERY_DIR="$NVIM_DATA_DIR/site/queries"
    mkdir -p "$SITE_QUERY_DIR"
    for query_src in "$TS_QUERY_SRC"/*/; do
        ln -sfn "${query_src%/}" "$SITE_QUERY_DIR/$(basename "$query_src")"
    done
    QUERY_COUNT=$(find "$SITE_QUERY_DIR" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
    echo -e "${GREEN}✓${NC} $QUERY_COUNT jeux de queries Treesitter liés"
else
    echo -e "${YELLOW}⚠${NC} Queries Treesitter absentes : la coloration restera vide."
fi

echo -e "\n${GREEN}[4/5]${NC} Installation de la chaîne Java..."
for java_component in jdtls java-debug java-test; do
    if [ -d "$java_component" ]; then
        backup "$HOME/.local/share/$java_component"
        mkdir -p "$HOME/.local/share/$java_component"
        cp -R "$java_component/." "$HOME/.local/share/$java_component/"
        echo -e "${GREEN}✓${NC} $java_component installé dans $HOME/.local/share/$java_component"
    else
        echo -e "${YELLOW}⚠${NC} $java_component non inclus dans ce bundle."
    fi
done

# Optional OL8 Java/Python toolchain. Scope its environment to Neovim only.
if [ -d tools ]; then
    if [ ! -x "$HOME/.local/share/neovim/bin/nvim" ]; then
        echo 'Erreur : la toolchain exige le runtime Neovim embarqué.' >&2
        exit 1
    fi
    backup "$HOME/.local/share/nvim-tools"
    cp -R tools "$HOME/.local/share/nvim-tools"
    # Remove the symlink before writing: never overwrite its runtime target.
    rm -f "$HOME/.local/bin/nvim"
    cat > "$HOME/.local/bin/nvim" <<'NVIM_WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
TOOLS="$HOME/.local/share/nvim-tools"
export PATH="$TOOLS/bin:$TOOLS/node/bin:$PATH"
export JDTLS_JAVA_HOME="${JDTLS_JAVA_HOME:-$TOOLS/jdk-25}"
export JAVA25_HOME="${JAVA25_HOME:-$TOOLS/jdk-25}"
exec "$HOME/.local/share/neovim/bin/nvim" "$@"
NVIM_WRAPPER
    chmod +x "$HOME/.local/bin/nvim"
    echo '✓ JDK 25, Node, Pyright et Ruff embarqués pour Neovim'
fi

echo -e "\n${GREEN}[5/5]${NC} Vérification du binaire blink.cmp..."
if ls "$LAZY_DIR"/blink.cmp/target/release/libblink_cmp_fuzzy.* &> /dev/null; then
    echo -e "${GREEN}✓${NC} Binaire fuzzy blink.cmp présent"
else
    echo -e "${YELLOW}⚠${NC} Binaire blink.cmp absent : vérifiez le repli Lua avant utilisation hors ligne."
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Installation terminée !${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${GREEN}Lancez Neovim maintenant:${NC} ${BLUE}nvim${NC}"
echo -e "Vérifiez :checkhealth ; les fonctions disponibles dépendent du contenu exporté."
echo -e "\n${YELLOW}À compléter au besoin (voir DEPENDENCIES.md):${NC}"
echo -e "- ripgrep (rg)  → grep du picker Snacks (<leader>g)"
echo -e "- fd            → recherche de fichiers, plus rapide"
if [ ! -d tools ]; then
    echo -e "- JDK adapté   → requis par jdtls (25 pour la release 1.61) (le serveur est là, pas la JVM)"
fi
echo -e "- lazygit       → <leader>lg"
echo -e "- autres serveurs LSP et formatters → selon le contenu du bundle"
