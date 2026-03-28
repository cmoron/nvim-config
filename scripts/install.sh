#!/usr/bin/env bash
# =============================================================================
# install.sh
# Installation classique de la config Neovim (système avec accès internet).
#
# Installe :
#   - La config init.lua dans ~/.config/nvim/
#   - Les serveurs LSP, formatters et outils CLI nécessaires
#   - Les plugins (lazy.nvim se bootstrap tout seul au premier lancement)
#   - Les parsers Treesitter (auto-installés au premier lancement)
#
# Usage :
#   bash scripts/install.sh           # installation complète
#   bash scripts/install.sh --check   # vérifie les dépendances sans installer
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
NVIM_CONFIG_DIR="$HOME/.config/nvim"

CHECK_ONLY=false
if [[ "${1:-}" == "--check" ]]; then
    CHECK_ONLY=true
fi

# --- Couleurs ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }

# --- Détection du package manager ---
detect_pm() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v brew &>/dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}

PM=$(detect_pm)

# --- Helpers ---
has() { command -v "$1" &>/dev/null; }

npm_install() {
    if has bun; then
        bun install -g "$@"
    elif has npm; then
        npm install -g "$@"
    else
        fail "Ni bun ni npm trouvé — impossible d'installer $*"
        return 1
    fi
}

# =============================================================================
echo "=== Vérification des prérequis ==="
# =============================================================================

MISSING=()

# Neovim >= 0.11
if has nvim; then
    NVIM_VER=$(nvim --version | head -1 | grep -oP '\d+\.\d+')
    NVIM_MAJOR=$(echo "$NVIM_VER" | cut -d. -f1)
    NVIM_MINOR=$(echo "$NVIM_VER" | cut -d. -f2)
    if (( NVIM_MAJOR == 0 && NVIM_MINOR < 11 )); then
        fail "Neovim $NVIM_VER détecté — version 0.11+ requise"
        MISSING+=("neovim>=0.11")
    else
        ok "Neovim $NVIM_VER"
    fi
else
    fail "Neovim non installé"
    MISSING+=("neovim")
fi

# Git (requis par lazy.nvim)
if has git; then ok "git"; else fail "git non installé"; MISSING+=("git"); fi

# ripgrep (requis par Telescope live_grep)
if has rg; then ok "ripgrep"; else fail "ripgrep non installé"; MISSING+=("ripgrep"); fi

# Node.js / Bun (pour les LSP JS/TS et prettier)
if has bun; then
    ok "bun $(bun --version 2>/dev/null)"
elif has node; then
    ok "node $(node --version 2>/dev/null)"
else
    fail "Ni bun ni node — nécessaire pour les LSP JS/TS"
    MISSING+=("nodejs|bun")
fi

# Python (pour pyright, ruff)
if has python3; then ok "python3"; else warn "python3 absent — LSP Python non fonctionnel"; fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo ""
    echo "Dépendances système manquantes : ${MISSING[*]}"
    case "$PM" in
        apt) echo "  sudo apt install neovim git ripgrep nodejs npm" ;;
        dnf) echo "  sudo dnf install neovim git ripgrep nodejs npm" ;;
        pacman) echo "  sudo pacman -S neovim git ripgrep nodejs npm" ;;
        brew) echo "  brew install neovim git ripgrep node" ;;
        *) echo "  Installer manuellement : ${MISSING[*]}" ;;
    esac
    if $CHECK_ONLY; then exit 1; fi
    echo ""
    read -rp "Continuer quand même ? [y/N] " ans
    [[ "$ans" =~ ^[yY]$ ]] || exit 1
fi

if $CHECK_ONLY; then
    echo ""
    echo "=== Vérification des outils de développement ==="
    check_tool() {
        if has "$1"; then ok "$1"; else warn "$1 absent"; fi
    }
    # LSP servers
    check_tool pyright
    check_tool bash-language-server
    check_tool typescript-language-server
    check_tool svelte-language-server
    check_tool rust-analyzer
    check_tool ruff
    # Formatters
    check_tool stylua
    check_tool prettier
    check_tool xmllint
    echo ""
    exit 0
fi

# =============================================================================
echo ""
echo "=== [1/3] Installation de la config ==="
# =============================================================================

mkdir -p "$NVIM_CONFIG_DIR"

if [ -f "$NVIM_CONFIG_DIR/init.lua" ]; then
    # Ne pas sauvegarder si c'est déjà un symlink vers notre repo
    if [ "$(readlink -f "$NVIM_CONFIG_DIR/init.lua")" != "$(readlink -f "$REPO_DIR/init.lua")" ]; then
        BACKUP="$NVIM_CONFIG_DIR/init.lua.bak-$(date +%Y%m%d%H%M%S)"
        warn "Backup de l'existant → $BACKUP"
        cp "$NVIM_CONFIG_DIR/init.lua" "$BACKUP"
    fi
fi

# Symlink plutôt que copie — les modifs au repo se propagent directement
ln -sf "$REPO_DIR/init.lua" "$NVIM_CONFIG_DIR/init.lua"
ok "init.lua → $NVIM_CONFIG_DIR/init.lua (symlink)"

# =============================================================================
echo ""
echo "=== [2/3] Installation des serveurs LSP et formatters ==="
# =============================================================================

install_if_missing() {
    local cmd="$1"
    local name="${2:-$1}"
    shift 2
    if has "$cmd"; then
        ok "$name (déjà installé)"
        return 0
    fi
    echo "  Installation de $name..."
    "$@" && ok "$name" || warn "Échec installation $name"
}

# --- LSP Servers ---

# pyright (Python type checker / LSP)
install_if_missing pyright pyright npm_install pyright

# bash-language-server
install_if_missing bash-language-server bash-language-server npm_install bash-language-server

# typescript-language-server (+ typescript requis)
install_if_missing typescript-language-server typescript-language-server npm_install typescript typescript-language-server

# svelte-language-server
install_if_missing svelteserver svelte-language-server npm_install svelte-language-server

# ruff (Python linter + formatter)
if has ruff; then
    ok "ruff (déjà installé)"
elif has uv; then
    echo "  Installation de ruff via uv..."
    uv tool install ruff && ok "ruff" || warn "Échec installation ruff"
elif has pip3; then
    echo "  Installation de ruff via pip..."
    pip3 install --user ruff && ok "ruff" || warn "Échec installation ruff"
else
    warn "ruff : ni uv ni pip3 trouvé — installer manuellement"
fi

# rust-analyzer (installé via rustup — on ne l'installe pas nous-mêmes)
if has rust-analyzer; then
    ok "rust-analyzer (déjà installé)"
else
    warn "rust-analyzer absent — installer via : rustup component add rust-analyzer"
fi

# --- Formatters ---

# stylua (Lua formatter)
if has stylua; then
    ok "stylua (déjà installé)"
elif has cargo; then
    echo "  Installation de stylua via cargo..."
    cargo install stylua && ok "stylua" || warn "Échec installation stylua"
else
    warn "stylua absent — installer via cargo install stylua"
fi

# prettier (JS/TS/HTML/CSS/JSON/YAML/MD formatter)
install_if_missing prettier prettier npm_install prettier

# xmllint (XML formatter — paquet système)
if has xmllint; then
    ok "xmllint (déjà installé)"
else
    case "$PM" in
        apt) warn "xmllint absent — sudo apt install libxml2-utils" ;;
        dnf) warn "xmllint absent — sudo dnf install libxml2" ;;
        pacman) warn "xmllint absent — sudo pacman -S libxml2" ;;
        brew) warn "xmllint absent — brew install libxml2" ;;
        *) warn "xmllint absent — installer le paquet libxml2" ;;
    esac
fi

# =============================================================================
echo ""
echo "=== [3/3] Bootstrap des plugins et parsers ==="
# =============================================================================

echo "  Lancement de nvim pour installer les plugins (lazy.nvim)..."
echo "  et les parsers Treesitter... (peut prendre 1-2 min)"
nvim --headless "+Lazy! sync" +qa 2>/dev/null && ok "Plugins installés" || warn "Lazy sync — vérifier manuellement avec :Lazy"

# =============================================================================
echo ""
echo "=== Installation terminée ==="
echo ""
echo "  Lancer nvim et vérifier :"
echo "    :checkhealth              ← état général"
echo "    :Lazy                     ← plugins"
echo "    :LspInfo                  ← serveurs LSP"
echo "    :ConformInfo              ← formatters"
echo ""
