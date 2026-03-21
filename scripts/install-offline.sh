#!/usr/bin/env bash
# =============================================================================
# install-offline.sh
# À exécuter sur Fedora Silverblue (dans le distrobox) après avoir copié
# le contenu de scripts/dist/ sur la machine cible.
#
# Usage :
#   # Copier dist/ sur la machine cible, puis :
#   cd /chemin/vers/dist
#   bash install-offline.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="$(uname -m)"

NVIM_CONFIG_DIR="$HOME/.config/nvim"
NVIM_DATA_DIR="$HOME/.local/share/nvim"

INIT_LUA="$SCRIPT_DIR/init.lua"
PLUGINS_BUNDLE="$SCRIPT_DIR/nvim-plugins.tar.gz"
PARSERS_BUNDLE="$SCRIPT_DIR/nvim-parsers-${ARCH}-linux.tar.gz"
JDTLS_BUNDLE="$SCRIPT_DIR/jdtls.tar.gz"

# Vérifications (jdtls.tar.gz est optionnel)
for f in "$INIT_LUA" "$PLUGINS_BUNDLE" "$PARSERS_BUNDLE"; do
    if [ ! -f "$f" ]; then
        echo "Erreur : fichier manquant : $f"
        exit 1
    fi
done

# ===========================================================================
echo "[1/3] Installation de la config nvim..."
# ===========================================================================

mkdir -p "$NVIM_CONFIG_DIR"

if [ -f "$NVIM_CONFIG_DIR/init.lua" ]; then
    BACKUP="$NVIM_CONFIG_DIR/init.lua.bak-$(date +%Y%m%d%H%M%S)"
    echo "  Backup de l'existant → $BACKUP"
    cp "$NVIM_CONFIG_DIR/init.lua" "$BACKUP"
fi

cp "$INIT_LUA" "$NVIM_CONFIG_DIR/init.lua"
echo "    → $NVIM_CONFIG_DIR/init.lua"

# ===========================================================================
echo "[2/3] Installation des plugins lazy..."
# ===========================================================================

mkdir -p "$NVIM_DATA_DIR"
tar -xzf "$PLUGINS_BUNDLE" -C "$NVIM_DATA_DIR"
echo "    → $NVIM_DATA_DIR/lazy/"

# ===========================================================================
echo "[3/3] Installation des parsers Treesitter..."
# ===========================================================================

TS_DIR="$NVIM_DATA_DIR/lazy/nvim-treesitter"
if [ ! -d "$TS_DIR" ]; then
    echo "Erreur : nvim-treesitter absent après extraction des plugins"
    exit 1
fi

tar -xzf "$PARSERS_BUNDLE" -C "$TS_DIR"
echo "    → $TS_DIR/parser/"

# ===========================================================================
echo "[4/4] Installation de jdtls (optionnel)..."
# ===========================================================================

if [ -f "$JDTLS_BUNDLE" ]; then
    mkdir -p "$HOME/.local/share"
    tar -xzf "$JDTLS_BUNDLE" -C "$HOME/.local/share"
    echo "    → $HOME/.local/share/jdtls/"
else
    echo "  jdtls.tar.gz absent — support Java non installé"
    echo "  → Voir README.md section 'Java (jdtls) sur Silverblue'"
fi

# ===========================================================================
echo ""
echo "Installation terminée. Lance nvim pour vérifier."
echo "  :checkhealth nvim-treesitter   ← vérifier les parsers"
echo "  :Lazy                          ← vérifier les plugins"
if [ ! -f "$JDTLS_BUNDLE" ]; then
    echo "  Java : suivre README.md pour installer jdtls manuellement"
fi
echo ""
