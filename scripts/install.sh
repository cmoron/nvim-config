#!/usr/bin/env bash
# =============================================================================
# install.sh — déploiement de la configuration Neovim (machine avec réseau)
#
# Pour une machine sans réseau, voir scripts/export-offline.sh.
# Portable Linux / macOS : pas de GNU-isme (grep -P, readlink -f, mktemp sans
# gabarit), et pas d'expansion de tableau vide, refusée par le bash 3.2 d'Apple.
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

Le serveur Java jdtls est installé depuis download.eclipse.org, à sa dernière
version épinglée, uniquement si un JDK 25+ est présent. L'adaptateur de debug et
le lanceur de tests Java suivent, extraits des extensions VS Code (seul canal
de distribution publié pour ces deux jars).

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
    log=$(tmpfile)
    "$@" >"$log" 2>&1 || rc=$?
    [[ $rc -ne 0 ]] && tail -8 "$log" | sed 's/^/      /'
    rm -f "$log"
    return $rc
}

has() { command -v "$1" &>/dev/null; }

# readlink -f est absent des BSD antérieurs à macOS 13. Ces chemins sont
# toujours des dossiers, donc cd -P suffit à résoudre les symlinks.
abspath() { (cd -P "$1" 2>/dev/null && pwd) || printf '%s' "$1"; }

# mktemp sans argument échoue sur BSD : on fournit un gabarit explicite.
tmpfile() { mktemp "${TMPDIR:-/tmp}/nvim-install.XXXXXX"; }

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

# Extrait les jars serveur d'une extension VS Code. C'est le seul canal de
# distribution publié pour l'adaptateur de debug comme pour le lanceur de
# tests : leurs dépôts ne joignent aucun binaire à leurs releases. L'URL
# `latest` dispense de découvrir la version, donc pas de jq à exiger.
# Pas de rafraîchissement automatique : supprimer le dossier pour retélécharger.
# $1 extension  $2 dossier cible  $3 libellé  $4 jar témoin
install_vscode_jars() {
    local ext="$1" dir="$2" label="$3" probe="$4"
    local url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/vscjava/vsextensions/$ext/latest/vspackage"

    if ! has unzip; then
        warn "unzip absent — $label non installé"; return 0
    elif compgen -G "$dir/$probe" >/dev/null; then
        ok "$label déjà présent"; return 0
    elif $DRY_RUN; then
        info "[dry-run] installerait $label → $dir"; return 0
    fi

    info "téléchargement de $label..."
    local vsix staging
    vsix=$(tmpfile)
    staging="$dir.staging-$$"
    # Le marketplace renvoie des 503 sporadiques : constatés sur deux appels
    # consécutifs encadrant un 200 sur la même URL. Sans retry, un build long
    # se casse sur un aléa de quelques secondes.
    if curl -fsSL --compressed --retry 3 --retry-all-errors --retry-delay 3 \
            -o "$vsix" "$url" \
       && unzip -qo "$vsix" 'extension/server/*.jar' -d "$staging" 2>/dev/null \
       && compgen -G "$staging/extension/server/$probe" >/dev/null; then
        # L'extension change de jars entre versions : on remplace, sans fusionner.
        rm -rf "$dir"
        mkdir -p "$dir"
        mv "$staging"/extension/server/*.jar "$dir/"
        rm -rf "$staging"
        ok "$label installé"
    else
        rm -rf "$staging"
        fail "$label : téléchargement ou extraction en échec"
    fi
    rm -f "$vsix"
}

pkg_install() {
    if has bun; then run bun install -g "$@"
    else warn "bun absent — impossible d'installer $*"; return 1; fi
}

echo -e "${BOLD}Configuration Neovim${NC} ${DIM}— $REPO_DIR${NC}"
$DRY_RUN && info "mode dry-run : aucune modification ne sera écrite"

# =============================================================================
step "Prérequis"
# =============================================================================

MISSING=""   # chaîne et non tableau : bash 3.2 + set -u

if has nvim; then
    NVIM_VER=$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if (( $(echo "$NVIM_VER" | cut -d. -f1) == 0 && $(echo "$NVIM_VER" | cut -d. -f2) < 12 )); then
        fail "Neovim $NVIM_VER — version 0.12+ requise"
        MISSING="$MISSING neovim>=0.12"
    else
        ok "Neovim $NVIM_VER"
    fi
else
    fail "Neovim non installé"; MISSING="$MISSING neovim"
fi

if has git; then ok "git"; else fail "git non installé"; MISSING="$MISSING git"; fi
if has rg; then ok "ripgrep"; else fail "ripgrep non installé"; MISSING="$MISSING ripgrep"; fi

# Plancher déclaré par le commit nvim-treesitter de lazy-lock.json.
TS_VERSION=$(tree-sitter --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
if ! has tree-sitter; then
    fail "tree-sitter absent — les parsers ne pourront pas être compilés"
    MISSING="$MISSING tree-sitter-cli"
elif [[ ! "$TS_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] \
    || (( BASH_REMATCH[1] == 0 && (BASH_REMATCH[2] < 26 || (BASH_REMATCH[2] == 26 && BASH_REMATCH[3] < 1)) )) \
    || ! tree-sitter build --help &>/dev/null; then
    fail "tree-sitter ${TS_VERSION:-inconnu} incompatible (0.26.1+ avec 'build' requis)"
    info "→ cargo install tree-sitter-cli, ou le binaire des releases GitHub"
    MISSING="$MISSING tree-sitter-cli>=0.26.1"
else
    ok "tree-sitter $(tree-sitter --version | grep -oE '[0-9]+(\.[0-9]+)*' | head -1)"
fi

if has bun; then ok "bun $(bun --version)"
else fail "bun absent — requis pour installer les outils JS"; MISSING="$MISSING bun"; fi
if has node; then ok "Node présent (lanceurs des outils JS)"
else fail "Node absent — requis par les lanceurs des outils JS"; MISSING="$MISSING nodejs"; fi

if has python3; then ok "python3"; else warn "python3 absent — LSP Python non fonctionnel"; fi

if [ -n "$MISSING" ]; then
    echo ""
    info "Paquets système manquants :$MISSING"
    case "$PM" in
        apt)    info "  sudo apt install git ripgrep nodejs ; installer Neovim 0.12+ et tree-sitter 0.26.1+ séparément" ;;
        dnf)    info "  sudo dnf install git ripgrep nodejs ; installer Neovim 0.12+ et tree-sitter 0.26.1+ séparément" ;;
        pacman) info "  sudo pacman -S neovim git ripgrep nodejs tree-sitter" ;;
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

ABSENT=""
ABSENT_COUNT=0
for entry in "${DEV_TOOLS[@]}"; do
    cmd="${entry%%:*}"; desc="${entry#*:}"
    if has "$cmd"; then
        ok "$(printf '%-28s' "$cmd") ${DIM}$desc${NC}"
    else
        warn "$(printf '%-28s' "$cmd") ${DIM}$desc${NC}"
        ABSENT="$ABSENT $cmd"; ABSENT_COUNT=$((ABSENT_COUNT + 1))
    fi
done

if $CHECK_ONLY; then
    step "Résumé"
    ok "$(( ${#DEV_TOOLS[@]} - ABSENT_COUNT ))/${#DEV_TOOLS[@]} outils présents"
    [ -n "$ABSENT" ] && info "absents :$ABSENT"
    echo ""
    [[ $FAILURES -gt 0 ]] && exit 1
    exit 0
fi

if [ -n "$MISSING" ] && ! $DRY_RUN; then
    echo ""
    read -rp "Prérequis manquants. Continuer quand même ? [y/N] " ans
    [[ "$ans" =~ ^[yY]$ ]] || exit 1
fi

# =============================================================================
step "[1/4] Déploiement de la configuration"
# =============================================================================

# Symlink du dossier entier, pas fichier par fichier : tout ajout au dépôt
# (ftplugin/, lazy-lock.json...) est déployé sans retoucher ce script.
# -n est indispensable : sans lui, ln -sf sur un symlink de dossier existant
# créerait le lien à l'intérieur de la cible.
run mkdir -p "$(dirname "$NVIM_CONFIG_DIR")"

ALREADY_DEPLOYED=false
if [ -L "$NVIM_CONFIG_DIR" ]; then
    if [ "$(abspath "$NVIM_CONFIG_DIR")" = "$(abspath "$REPO_DIR")" ]; then
        ALREADY_DEPLOYED=true
        ok "déjà déployé → $REPO_DIR"
    else
        warn "symlink existant vers $(abspath "$NVIM_CONFIG_DIR") — remplacé"
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
step "[2/4] Serveurs LSP et formatters"
# =============================================================================

if [ -z "$ABSENT" ]; then
    ok "tout est déjà installé"
else
    for cmd in $ABSENT; do   # non quoté : découpage voulu
        case "$cmd" in
            pyright|bash-language-server|prettier)
                if pkg_install "$cmd"; then installed "$cmd"; else warn "échec : $cmd"; fi ;;
            typescript-language-server)
                if pkg_install typescript typescript-language-server; then installed "$cmd"; else warn "échec : $cmd"; fi ;;
            svelteserver)
                if pkg_install svelte-language-server; then installed "$cmd"; else warn "échec : $cmd"; fi ;;
            ruff)
                if has uv; then
                    if run uv tool install ruff; then installed "ruff"; else warn "échec : ruff"; fi
                else warn "ruff : uv absent — à installer manuellement"; fi ;;
            stylua)
                if has cargo; then
                    if run cargo install stylua; then installed "stylua"; else warn "échec : stylua"; fi
                else warn "stylua : cargo absent — cargo install stylua"; fi ;;
            rust-analyzer)
                warn "rust-analyzer : rustup component add rust-analyzer" ;;
            gopls)
                if has go; then
                    if run go install golang.org/x/tools/gopls@latest; then installed "gopls"; else warn "échec : gopls"; fi
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
step "[3/4] Serveur Java (jdtls + debug + tests)"
# =============================================================================

# jdtls n'est pas distribué par un gestionnaire de paquets : on le tire du
# site Eclipse. Épingler la release qualifiée avec le JDK 25 : un snapshot
# peut relever le plancher Java via une dépendance Eclipse transitive.
JDTLS_DIR="$HOME/.local/share/jdtls"
JDTLS_BASE="https://download.eclipse.org/jdtls/milestones/1.61.0"
JDTLS_STAMP="$JDTLS_DIR/.installed-from"

JDEBUG_DIR="$HOME/.local/share/java-debug"
JTEST_DIR="$HOME/.local/share/java-test"

# macOS fournit un stub /usr/bin/java qui échoue faute de JDK : la présence de
# la commande ne prouve rien, seule sa sortie compte. Le `|| true` est vital,
# sinon pipefail fait sortir le script sur ce stub.
# `openjdk version "25.0.2"` → 25 ; `"1.8.0_..."` → 1, donc rejeté plus bas.
JAVA_CMD="${JDTLS_JAVA_HOME:+$JDTLS_JAVA_HOME/bin/}java"
JAVA_MAJOR=$("$JAVA_CMD" -version 2>&1 | head -1 | sed -E 's/.*version "([0-9]+).*/\1/' || true)
# Si le motif ne matche pas, sed renvoie la ligne entière : on neutralise.
case "$JAVA_MAJOR" in ''|*[!0-9]*) JAVA_MAJOR=0 ;; esac

if (( JAVA_MAJOR == 0 )); then
    warn "aucun JDK utilisable détecté — jdtls non installé (49 Mo épargnés)"
    info "→ relancer ce script après avoir installé un JDK 25+"
elif (( JAVA_MAJOR < 25 )); then
    warn "JDK trop ancien pour jdtls (25+ requis)"
    info "→ un JDK 25+ peut coexister avec celui-ci"
else
    JDTLS_LATEST="jdt-language-server-1.61.0-202609031315.tar.gz"
    if [ -f "$JDTLS_STAMP" ] && [ "$(cat "$JDTLS_STAMP")" = "$JDTLS_LATEST" ]; then
        ok "jdtls à jour ($(echo "$JDTLS_LATEST" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1))"
    elif $DRY_RUN; then
        info "[dry-run] installerait $JDTLS_LATEST (~49 Mo) → $JDTLS_DIR"
    else
        info "téléchargement de jdtls $(echo "$JDTLS_LATEST" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) (~49 Mo)..."
        # Staging à côté de la cible : même système de fichiers, donc la
        # permutation finale est un simple rename.
        STAGING="$JDTLS_DIR.staging-$$"
        mkdir -p "$STAGING"
        if curl -fsSL "$JDTLS_BASE/$JDTLS_LATEST" | tar -xz -C "$STAGING" 2>/dev/null \
           && compgen -G "$STAGING/plugins/org.eclipse.equinox.launcher_*.jar" >/dev/null; then
            # L'archive s'extrait à plat : écraser laisserait cohabiter les jars
            # des deux versions. On permute.
            if [ -d "$JDTLS_DIR" ]; then
                rm -rf "$JDTLS_DIR.old"
                mv "$JDTLS_DIR" "$JDTLS_DIR.old"
            fi
            mv "$STAGING" "$JDTLS_DIR"
            echo "$JDTLS_LATEST" > "$JDTLS_STAMP"
            rm -rf "$JDTLS_DIR.old"
            ok "jdtls $(echo "$JDTLS_LATEST" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) installé"
        else
            rm -rf "$STAGING"
            fail "téléchargement ou extraction de jdtls en échec — installation précédente intacte"
        fi
    fi

    install_vscode_jars vscode-java-debug "$JDEBUG_DIR" \
        "adaptateur de debug Java (~3 Mo)" 'com.microsoft.java.debug.plugin-*.jar'
    install_vscode_jars vscode-java-test "$JTEST_DIR" \
        "lanceur de tests Java (~5 Mo)" 'com.microsoft.java.test.plugin-*.jar'
fi

# =============================================================================
step "[4/4] Plugins"
# =============================================================================

if $DRY_RUN; then
    info "[dry-run] nvim --headless +Lazy! restore +qa"
else
    info "installation aux versions de lazy-lock.json (1-2 min)..."
    # restore, pas sync : sync flotterait vers le dernier commit de chaque
    # plugin et réécrirait le lockfile.
    LAZY_LOG=$(tmpfile)
    if nvim --headless "+Lazy! restore" +qa >"$LAZY_LOG" 2>&1; then
        # Un échec partiel peut sortir en 0 : on ne se fie pas au code retour seul.
        if grep -qiE '^[[:space:]]*(error|failed)' "$LAZY_LOG"; then
            fail "Lazy restore a signalé des erreurs :"
            grep -iE '^[[:space:]]*(error|failed)' "$LAZY_LOG" | head -10 | sed 's/^/      /'
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

  Les parsers Treesitter sont installés au premier lancement avec interface.
  Le build offline les compile explicitement et attend leur installation.

EOF
