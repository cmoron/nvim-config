#!/usr/bin/env bash
# =============================================================================
# build-offline.sh
# Génère un bundle nvim déployable sur Fedora Silverblue (offline/distrobox)
# À exécuter sur WSL2/Ubuntu avec accès internet.
#
# Produit dans scripts/dist/ :
#   init.lua                             → ~/.config/nvim/init.lua
#   nvim-plugins.tar.gz                  → décompresser dans ~/.local/share/nvim/
#   nvim-parsers-<arch>-linux.tar.gz     → décompresser dans
#                                          ~/.local/share/nvim/lazy/nvim-treesitter/
#
# Sur Silverblue, lancer scripts/install-offline.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$SCRIPT_DIR/dist"
LAZY_ROOT="$HOME/.local/share/nvim/lazy"
PARSER_DIR="$LAZY_ROOT/nvim-treesitter/parser"
ARCH="$(uname -m)"

# Liste des parsers à pré-compiler pour le bundle offline
OFFLINE_PARSERS=(
    lua vim vimdoc
    javascript typescript
    html css
    python bash
    rust svelte
    java
    json yaml toml
    markdown
)

mkdir -p "$DIST_DIR"

# ===========================================================================
echo "[1/4] Génération de init.lua offline..."
# ===========================================================================

cp "$REPO_DIR/init.lua" "$DIST_DIR/init.lua"

# Patch: désactiver l'auto-install (pas de gcc / réseau sur offline)
sed -i 's/auto_install = true,/auto_install = false,/' "$DIST_DIR/init.lua"

# Patch: étendre ensure_installed avec la liste complète offline
PARSER_LIST=$(printf '"%s", ' "${OFFLINE_PARSERS[@]}")
PARSER_LIST="{ ${PARSER_LIST%, } }"
sed -i "s/ensure_installed = {[^}]*}/ensure_installed = $PARSER_LIST/" "$DIST_DIR/init.lua"

# Patch: remplacer le bootstrap lazy (git clone) par un guard offline
python3 - "$DIST_DIR/init.lua" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path) as f:
    content = f.read()

# Remplace le bloc bootstrap lazy (git clone) par un guard offline
pattern = r'(-- Installer lazy\.nvim si pas déjà fait\n)local lazypath.*?vim\.opt\.rtp:prepend\(lazypath\)'
replacement = (
    '-- Bundle offline : lazy.nvim doit être présent dans stdpath("data")/lazy/\n'
    'local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"\n'
    'if not vim.loop.fs_stat(lazypath) then\n'
    '    error("lazy.nvim introuvable. Décompresser le bundle plugins dans ~/.local/share/nvim/")\n'
    'end\n'
    'vim.opt.rtp:prepend(lazypath)'
)

new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
if new_content == content:
    print("  WARN: bootstrap block non trouvé, vérifier manuellement init.lua", file=sys.stderr)

with open(path, 'w') as f:
    f.write(new_content)
PYEOF

echo "    → $DIST_DIR/init.lua"

# ===========================================================================
echo "[2/4] Compilation des parsers Treesitter..."
# ===========================================================================

if [ ! -d "$LAZY_ROOT/nvim-treesitter" ]; then
    echo "Erreur : nvim-treesitter absent de $LAZY_ROOT"
    echo "Lance nvim une fois et attends que lazy installe les plugins."
    exit 1
fi

nvim --headless -l "$SCRIPT_DIR/offline-tsconfig.lua" -- "${OFFLINE_PARSERS[@]}"
echo "    → $PARSER_DIR"

# ===========================================================================
echo "[3/4] Bundle des plugins lazy..."
# ===========================================================================

if [ ! -d "$LAZY_ROOT" ]; then
    echo "Erreur : répertoire lazy introuvable : $LAZY_ROOT"
    exit 1
fi

PLUGINS_BUNDLE="$DIST_DIR/nvim-plugins.tar.gz"
# On bundle tout ~/.local/share/nvim/lazy/ (plugins + lazy.nvim lui-même)
tar -czf "$PLUGINS_BUNDLE" -C "$HOME/.local/share/nvim" "lazy"
echo "    → $PLUGINS_BUNDLE ($(du -sh "$PLUGINS_BUNDLE" | cut -f1))"

# ===========================================================================
echo "[4/5] Bundle des parsers Treesitter..."
# ===========================================================================

PARSERS_BUNDLE="$DIST_DIR/nvim-parsers-${ARCH}-linux.tar.gz"
tar -czf "$PARSERS_BUNDLE" -C "$(dirname "$PARSER_DIR")" "parser"
echo "    → $PARSERS_BUNDLE ($(du -sh "$PARSERS_BUNDLE" | cut -f1))"

# ===========================================================================
echo "[5/6] Bundle de jdtls..."
# ===========================================================================

JDTLS_DIR="$HOME/.local/share/jdtls"
if [ ! -d "$JDTLS_DIR" ]; then
    echo "  WARN: jdtls absent de $JDTLS_DIR — support Java non bundlé"
    echo "  → Installer jdtls : scripts/install-jdtls.sh"
else
    JDTLS_BUNDLE="$DIST_DIR/jdtls.tar.gz"
    tar -czf "$JDTLS_BUNDLE" -C "$(dirname "$JDTLS_DIR")" "jdtls"
    echo "    → $JDTLS_BUNDLE ($(du -sh "$JDTLS_BUNDLE" | cut -f1))"
fi

# ===========================================================================
echo "[6/6] Copie des scripts et README..."
# ===========================================================================

cp "$SCRIPT_DIR/install-offline.sh" "$DIST_DIR/install-offline.sh"
chmod +x "$DIST_DIR/install-offline.sh"

# Régénérer le README avec la date de build
sed -i "s/^# Bundle Neovim/# Bundle Neovim — $(date +%Y-%m-%d)/" "$DIST_DIR/README.md" 2>/dev/null || true

echo "    → $DIST_DIR/install-offline.sh"
echo "    → $DIST_DIR/README.md"

# ===========================================================================
echo ""
echo "Bundle complet dans $DIST_DIR :"
ls -lh "$DIST_DIR"
echo ""
echo "Sur Silverblue, copier les fichiers du dist/ puis lancer :"
echo "  bash install-offline.sh"
echo ""
