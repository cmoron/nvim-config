#!/usr/bin/env bash
# =============================================================================
# install.sh — déploiement de la configuration Neovim (machine avec réseau)
#
# Pour une machine sans réseau, voir export-offline.sh à la racine du dépôt.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
NVIM_CONFIG_DIR="$HOME/.config/nvim"

# --- Couleurs (désactivées si la sortie n'est pas un terminal) ---
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    BLUE='\033[0;34m'; DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; DIM=''; BOLD=''; NC=''
fi

FAILURES=0
WARNINGS=0

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAILURES=$((FAILURES + 1)); }
info() { echo -e "  ${DIM}$1${NC}"; }
step() { echo -e "\n${BOLD}${BLUE}$1${NC}"; }

usage() {
    cat <<EOF
${BOLD}Usage:${NC} install.sh [OPTIONS]

Déploie la configuration Neovim de ce dépôt et installe ses dépendances
(serveurs LSP, formatters, plugins aux versions de lazy-lock.json).

${BOLD}Options:${NC}
  -c, --check      Vérifie prérequis et outils, n'installe et ne modifie rien
  -n, --dry-run    Affiche les actions sans les exécuter
  -h, --help       Affiche cette aide

${BOLD}Détails:${NC}
  La config est déployée par symlink de ${DIM}$NVIM_CONFIG_DIR${NC} vers le dépôt :
  toute modification du dépôt est active immédiatement, et les fichiers
  ajoutés (ftplugin/, lua/...) sont pris en compte sans retoucher ce script.

  Une config existante est déplacée vers ${DIM}<chemin>.bak-<horodatage>${NC}.

${BOLD}Codes de sortie:${NC}
  0  succès (des avertissements restent possibles)
  1  au moins un échec
  2  erreur d'utilisation
EOF
}

# --- Parsing des arguments ---
CHECK_ONLY=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--check)   CHECK_ONLY=true; shift ;;
        -n|--dry-run) DRY_RUN=true; shift ;;
        -h|--help)    usage; exit 0 ;;
        *)
            echo -e "${RED}Erreur:${NC} option inconnue : $1" >&2
            echo "Essayez : install.sh --help" >&2
            exit 2
            ;;
    esac
done

# Exécute une commande sans polluer stdout. Sa sortie n'est montrée qu'en cas
# d'échec — un installeur bavard cache ce qui a vraiment raté.
# En dry-run, affiche l'action sans l'exécuter.
run() {
    if $DRY_RUN; then
        info "[dry-run] $*"
        return 0
    fi
    local log rc=0
    log=$(mktemp)
    "$@" >"$log" 2>&1 || rc=$?
    [[ $rc -ne 0 ]] && tail -8 "$log" | sed 's/^/      /'
    rm -f "$log"
    return $rc
}

has() { command -v "$1" &>/dev/null; }

# Succès d'une installation : muet en dry-run, où rien n'a été installé.
installed() { $DRY_RUN || ok "$1"; }

detect_pm() {
    if has apt-get; then echo "apt"
    elif has dnf;   then echo "dnf"
    elif has pacman; then echo "pacman"
    elif has brew;  then echo "brew"
    else echo "unknown"; fi
}
PM=$(detect_pm)

pkg_install() {
    if has bun; then run bun install -g "$@"
    elif has npm; then run npm install -g "$@"
    else fail "Ni bun ni npm — impossible d'installer $*"; return 1; fi
}

echo -e "${BOLD}Configuration Neovim${NC} ${DIM}— $REPO_DIR${NC}"
$DRY_RUN && info "mode dry-run : aucune modification ne sera écrite"

# =============================================================================
step "Prérequis"
# =============================================================================

MISSING=()

if has nvim; then
    NVIM_VER=$(nvim --version | head -1 | grep -oP '\d+\.\d+')
    if (( $(echo "$NVIM_VER" | cut -d. -f1) == 0 && $(echo "$NVIM_VER" | cut -d. -f2) < 11 )); then
        fail "Neovim $NVIM_VER — version 0.11+ requise"
        MISSING+=("neovim>=0.11")
    else
        ok "Neovim $NVIM_VER"
    fi
else
    fail "Neovim non installé"; MISSING+=("neovim")
fi

if has git; then ok "git"; else fail "git non installé"; MISSING+=("git"); fi
if has rg; then ok "ripgrep"; else fail "ripgrep non installé"; MISSING+=("ripgrep"); fi

# nvim-treesitter branche main compile via `tree-sitter build`, sous-commande
# absente avant 0.25 (dont la version packagée par apt). On teste la capacité,
# pas le numéro de version.
if ! has tree-sitter; then
    fail "tree-sitter absent — les parsers ne pourront pas être compilés"
    MISSING+=("tree-sitter-cli")
elif ! tree-sitter build --help &>/dev/null; then
    fail "tree-sitter $(tree-sitter --version | grep -oP '[\d.]+' | head -1) trop ancien (pas de sous-commande 'build')"
    info "→ cargo install tree-sitter-cli, ou le binaire des releases GitHub"
    MISSING+=("tree-sitter-cli>=0.25")
else
    ok "tree-sitter $(tree-sitter --version | grep -oP '[\d.]+' | head -1)"
fi

if has bun; then ok "bun $(bun --version)"
elif has node; then ok "node $(node --version)"
else fail "Ni bun ni node — requis pour les LSP JS/TS"; MISSING+=("bun|nodejs"); fi

if has python3; then ok "python3"; else warn "python3 absent — LSP Python non fonctionnel"; fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo ""
    info "Paquets système manquants : ${MISSING[*]}"
    case "$PM" in
        apt)    info "  sudo apt install neovim git ripgrep nodejs npm" ;;
        dnf)    info "  sudo dnf install neovim git ripgrep nodejs npm" ;;
        pacman) info "  sudo pacman -S neovim git ripgrep nodejs npm" ;;
        brew)   info "  brew install neovim git ripgrep node" ;;
        *)      info "  à installer manuellement" ;;
    esac
fi

# =============================================================================
step "Outils de développement"
# =============================================================================

# nom_commande:description
DEV_TOOLS=(
    "pyright:LSP Python"
    "bash-language-server:LSP Bash"
    "typescript-language-server:LSP JS/TS"
    "svelteserver:LSP Svelte"
    "rust-analyzer:LSP Rust"
    "gopls:LSP Go"
    "ruff:lint/format Python"
    "stylua:format Lua"
    "prettier:format JS/TS/HTML/CSS/JSON/YAML/MD"
    "xmllint:format XML"
)

ABSENT=()
for entry in "${DEV_TOOLS[@]}"; do
    cmd="${entry%%:*}"; desc="${entry#*:}"
    if has "$cmd"; then
        ok "$(printf '%-28s' "$cmd") ${DIM}$desc${NC}"
    else
        warn "$(printf '%-28s' "$cmd") ${DIM}$desc${NC}"
        ABSENT+=("$cmd")
    fi
done

if $CHECK_ONLY; then
    step "Résumé"
    ok "$(( ${#DEV_TOOLS[@]} - ${#ABSENT[@]} ))/${#DEV_TOOLS[@]} outils présents"
    [[ ${#ABSENT[@]} -gt 0 ]] && info "absents : ${ABSENT[*]}"
    echo ""
    [[ $FAILURES -gt 0 ]] && exit 1
    exit 0
fi

if [[ ${#MISSING[@]} -gt 0 ]] && ! $DRY_RUN; then
    echo ""
    read -rp "Prérequis manquants. Continuer quand même ? [y/N] " ans
    [[ "$ans" =~ ^[yY]$ ]] || exit 1
fi

# =============================================================================
step "[1/3] Déploiement de la configuration"
# =============================================================================

# Symlink du dossier entier, pas fichier par fichier : tout ajout au dépôt
# (ftplugin/, lazy-lock.json...) est déployé sans retoucher ce script.
# -n est indispensable : sans lui, ln -sf sur un symlink de dossier existant
# créerait le lien à l'intérieur de la cible.
run mkdir -p "$(dirname "$NVIM_CONFIG_DIR")"

ALREADY_DEPLOYED=false
if [ -L "$NVIM_CONFIG_DIR" ]; then
    if [ "$(readlink -f "$NVIM_CONFIG_DIR")" = "$(readlink -f "$REPO_DIR")" ]; then
        ALREADY_DEPLOYED=true
        ok "déjà déployé → $REPO_DIR"
    else
        warn "symlink existant vers $(readlink -f "$NVIM_CONFIG_DIR") — remplacé"
        run rm "$NVIM_CONFIG_DIR"
    fi
elif [ -e "$NVIM_CONFIG_DIR" ]; then
    BACKUP="$NVIM_CONFIG_DIR.bak-$(date +%Y%m%d%H%M%S)"
    warn "config existante déplacée → $BACKUP"
    run mv "$NVIM_CONFIG_DIR" "$BACKUP"
fi

if ! $ALREADY_DEPLOYED; then
    run ln -sfn "$REPO_DIR" "$NVIM_CONFIG_DIR"
    ok "$NVIM_CONFIG_DIR → $REPO_DIR"
fi

# =============================================================================
step "[2/3] Serveurs LSP et formatters"
# =============================================================================

if [[ ${#ABSENT[@]} -eq 0 ]]; then
    ok "tout est déjà installé"
else
    for cmd in "${ABSENT[@]}"; do
        case "$cmd" in
            pyright|bash-language-server|prettier)
                pkg_install "$cmd" && installed "$cmd" || warn "échec : $cmd" ;;
            typescript-language-server)
                pkg_install typescript typescript-language-server && installed "$cmd" || warn "échec : $cmd" ;;
            svelteserver)
                pkg_install svelte-language-server && installed "$cmd" || warn "échec : $cmd" ;;
            ruff)
                if has uv; then run uv tool install ruff && installed "ruff" || warn "échec : ruff"
                elif has pip3; then run pip3 install --user ruff && installed "ruff" || warn "échec : ruff"
                else warn "ruff : ni uv ni pip3 — à installer manuellement"; fi ;;
            stylua)
                if has cargo; then run cargo install stylua && installed "stylua" || warn "échec : stylua"
                else warn "stylua : cargo absent — cargo install stylua"; fi ;;
            rust-analyzer)
                warn "rust-analyzer : rustup component add rust-analyzer" ;;
            gopls)
                if has go; then run go install golang.org/x/tools/gopls@latest && installed "gopls" || warn "échec : gopls"
                else warn "gopls : go absent — https://go.dev/dl/"; fi ;;
            xmllint)
                case "$PM" in
                    apt)    warn "xmllint : sudo apt install libxml2-utils" ;;
                    dnf)    warn "xmllint : sudo dnf install libxml2" ;;
                    pacman) warn "xmllint : sudo pacman -S libxml2" ;;
                    brew)   warn "xmllint : brew install libxml2" ;;
                    *)      warn "xmllint : installer le paquet libxml2" ;;
                esac ;;
        esac
    done
fi

# =============================================================================
step "[3/3] Plugins et parsers Treesitter"
# =============================================================================

if $DRY_RUN; then
    info "[dry-run] nvim --headless +Lazy! restore +qa"
else
    info "installation aux versions de lazy-lock.json (1-2 min)..."
    # restore, pas sync : sync flotterait vers le dernier commit de chaque
    # plugin et réécrirait le lockfile.
    LAZY_LOG=$(mktemp)
    if nvim --headless "+Lazy! restore" +qa >"$LAZY_LOG" 2>&1; then
        # Un échec partiel peut sortir en 0 : on ne se fie pas au code retour seul.
        if grep -qiE '^\s*(error|failed)' "$LAZY_LOG"; then
            fail "Lazy restore a signalé des erreurs :"
            grep -iE '^\s*(error|failed)' "$LAZY_LOG" | head -10 | sed 's/^/      /'
        else
            PLUGIN_COUNT=$(python3 -c "import json;print(len(json.load(open('$REPO_DIR/lazy-lock.json'))))" 2>/dev/null || echo "?")
            ok "$PLUGIN_COUNT plugins installés"
        fi
    else
        fail "Lazy restore a échoué :"
        tail -20 "$LAZY_LOG" | sed 's/^/      /'
    fi
    rm -f "$LAZY_LOG"
fi

# =============================================================================
step "Résumé"
# =============================================================================

if [[ $FAILURES -gt 0 ]]; then
    fail "$FAILURES échec(s), $WARNINGS avertissement(s)"
    echo ""
    exit 1
fi

if [[ $WARNINGS -gt 0 ]]; then
    ok "installation terminée, $WARNINGS avertissement(s)"
else
    ok "installation terminée"
fi

cat <<EOF

  Vérifier dans nvim :
    :checkhealth     état général
    :Lazy            plugins
    :ConformInfo     formatters

EOF
