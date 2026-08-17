#!/usr/bin/env bash
# ============================================================================
# Script d'export de la configuration Neovim pour installation offline
#
# Stratégie : copier les plugins TELS QU'INSTALLÉS localement
# (~/.local/share/nvim/lazy/) plutôt que de re-cloner une liste en dur.
# Avantages :
#   - pas de liste de plugins à maintenir (elle dérivait à chaque migration)
#   - le binaire fuzzy précompilé de blink.cmp est inclus
#   - les branches pinées (nvim-treesitter main) sont respectées
# Les parsers treesitter (branche main) sont copiés depuis
# ~/.local/share/nvim/site/parser/ (binaires arm64 macOS : la cible doit
# avoir la même architecture/OS).
# ============================================================================

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Export configuration Neovim (offline)${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Chemins ancrés sur le dépôt, pas sur le cwd : le script est lançable depuis
# n'importe où, et les artefacts atterrissent dans dist/ plutôt qu'à la racine.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$REPO_DIR/dist"

EXPORT_DIR="$DIST_DIR/nvim-config-offline"
ARCHIVE="$DIST_DIR/nvim-config-offline.tar.gz"
PLUGINS_DIR="$EXPORT_DIR/plugins"
LAZY_DIR="$HOME/.local/share/nvim/lazy"
PARSER_DIR="$HOME/.local/share/nvim/site/parser"

if [ ! -d "$LAZY_DIR" ]; then
    echo -e "${RED}Erreur: $LAZY_DIR introuvable. Lancez Neovim une fois d'abord.${NC}"
    exit 1
fi

# Créer le dossier d'export
echo -e "${GREEN}[1/6]${NC} Création de la structure d'export..."
rm -rf "$EXPORT_DIR"
mkdir -p "$DIST_DIR"
mkdir -p "$PLUGINS_DIR"
mkdir -p "$EXPORT_DIR/config"

# Trace de la plateforme d'export : les parsers, le binaire fuzzy de blink et
# l'éventuel runtime nvim sont des binaires natifs. L'install refuse de poser
# un bundle étranger plutôt que de laisser découvrir la panne à l'usage.
printf '%s %s\n' "$(uname -s)" "$(uname -m)" > "$EXPORT_DIR/PLATFORM"

# Copier les fichiers de configuration
echo -e "${GREEN}[2/6]${NC} Copie des fichiers de configuration..."
cp "$REPO_DIR/init.lua" "$EXPORT_DIR/config/"
if [ -f "$REPO_DIR/lazy-lock.json" ]; then
    cp "$REPO_DIR/lazy-lock.json" "$EXPORT_DIR/config/"
fi

# Copier les plugins tels qu'installés (inclut le binaire précompilé de blink.cmp)
echo -e "\n${GREEN}[3/6]${NC} Copie des plugins installés..."
cp -R "$LAZY_DIR/." "$PLUGINS_DIR/"
PLUGIN_COUNT=$(ls -1 "$PLUGINS_DIR" | wc -l | tr -d ' ')
echo -e "${GREEN}✓${NC} $PLUGIN_COUNT plugins copiés"

# Nettoyer les dossiers .git pour économiser de l'espace
find "$PLUGINS_DIR" -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true

# Élaguer les parsers hérités de la branche master : treesitter main lit
# site/parser (exporté à l'étape suivante), jamais ce dossier.
rm -rf "$PLUGINS_DIR/nvim-treesitter/parser"

# blink.cmp compare le fichier `version` de son binaire au tag git du plugin
# pour décider s'il doit retélécharger. Les .git venant d'être supprimés, il ne
# trouve plus de tag, conclut « périmé », tente un téléchargement et retombe
# sur son implémentation Lua faute de réseau. Sans ce fichier, il reconnaît le
# cas « binaire posé à la main » et charge le .so tel quel (download/init.lua).
rm -f "$PLUGINS_DIR"/blink.cmp/target/release/version \
      "$PLUGINS_DIR"/blink.cmp/target/release/*.sha256

# Copier les parsers Treesitter pré-compilés (branche main : site/parser)
echo -e "\n${GREEN}[4/6]${NC} Copie des parsers Treesitter..."
TREESITTER_PARSER_DEST="$EXPORT_DIR/treesitter-parsers"
if [ -d "$PARSER_DIR" ]; then
    mkdir -p "$TREESITTER_PARSER_DEST"
    cp "$PARSER_DIR"/*.so "$TREESITTER_PARSER_DEST/"
    PARSER_COUNT=$(ls -1 "$TREESITTER_PARSER_DEST"/*.so 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}✓${NC} $PARSER_COUNT parsers copiés"
else
    echo -e "${YELLOW}⚠${NC} Parsers Treesitter non trouvés dans $PARSER_DIR."
    echo -e "  Lancez Neovim une fois pour les compiler."
fi

# Copier la chaîne Java : jdtls vient d'Eclipse, l'adaptateur de debug et le
# lanceur de tests du marketplace VS Code. Aucun des trois n'est distribué en
# rpm ou en npm, donc aucun ne s'attrape depuis une machine sans réseau.
echo -e "\n${GREEN}[5/6]${NC} Copie de la chaîne Java (jdtls, debug, tests)..."
for java_component in jdtls java-debug java-test; do
    src="$HOME/.local/share/$java_component"
    if [ -d "$src" ]; then
        cp -R "$src" "$EXPORT_DIR/$java_component"
        echo -e "${GREEN}✓${NC} $java_component copié ($(du -sh "$EXPORT_DIR/$java_component" | cut -f1))"
    else
        echo -e "${YELLOW}⚠${NC} $java_component absent de $src — non embarqué."
    fi
done

# Runtime Neovim : la config exige 0.12+ (nvim-treesitter branche main), que
# les dépôts d'une distribution ne servent pas toujours. NVIM_TARBALL, posé par
# export-offline-linux.sh, rend le bundle indépendant du gestionnaire de
# paquets de la cible.
echo -e "\n${GREEN}[6/6]${NC} Copie du runtime Neovim..."
if [ -n "${NVIM_TARBALL:-}" ] && [ -f "$NVIM_TARBALL" ]; then
    cp "$NVIM_TARBALL" "$EXPORT_DIR/$(basename "$NVIM_TARBALL")"
    echo -e "${GREEN}✓${NC} $(basename "$NVIM_TARBALL") embarqué"
else
    echo -e "${YELLOW}⚠${NC} Pas de NVIM_TARBALL — Neovim 0.12+ devra exister sur la cible."
fi

# Créer le script d'installation
echo -e "\n${GREEN}Création du script d'installation...${NC}"
cat > "$EXPORT_DIR/install.sh" << 'INSTALL_SCRIPT'
#!/usr/bin/env bash
# ============================================================================
# Script d'installation de la configuration Neovim (offline)
# ============================================================================

set -e

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
        echo -e "${YELLOW}Pour passer outre malgré tout: rm PLATFORM${NC}"
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

# Runtime Neovim embarqué : extrait sous ~/.local/share, exposé via
# ~/.local/bin. Aucune écriture hors du HOME, donc utilisable sans droits root,
# y compris sur un système à racine immuable.
NVIM_ARCHIVE=$(ls nvim-linux-*.tar.gz 2>/dev/null | head -1 || true)
NVIM_VERSION=$(nvim_major_minor || echo "0.0")
NVIM_MINOR=$(echo "${NVIM_VERSION:-0.0}" | cut -d. -f2)

if [ -n "$NVIM_ARCHIVE" ] && { ! command -v nvim &> /dev/null || [ "${NVIM_MINOR:-0}" -lt 12 ]; }; then
    echo -e "${BLUE}→${NC} Installation du runtime Neovim embarqué ($NVIM_ARCHIVE)..."
    rm -rf "$HOME/.local/share/neovim"
    mkdir -p "$HOME/.local/share/neovim" "$HOME/.local/bin"
    # --strip-components : l'archive officielle a un dossier racine versionné.
    tar -xzf "$NVIM_ARCHIVE" -C "$HOME/.local/share/neovim" --strip-components=1
    ln -sf "$HOME/.local/share/neovim/bin/nvim" "$HOME/.local/bin/nvim"
    export PATH="$HOME/.local/bin:$PATH"
    echo -e "${GREEN}✓${NC} Neovim installé dans ~/.local/share/neovim"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) echo -e "${YELLOW}⚠${NC} Ajoutez ~/.local/bin à votre PATH" ;;
    esac
fi

if ! command -v nvim &> /dev/null; then
    echo -e "${RED}Erreur: Neovim n'est pas installé${NC}"
    echo -e "Installez Neovim >= 0.12 avant de continuer"
    exit 1
fi

NVIM_VERSION=$(nvim_major_minor || echo "0.0")
echo -e "${BLUE}→${NC} Neovim version: $NVIM_VERSION"
if [ "$(echo "$NVIM_VERSION" | cut -d. -f2)" -lt 12 ]; then
    echo -e "${YELLOW}Attention:${NC} cette configuration requiert Neovim >= 0.12"
    echo -e "(nvim-treesitter branche main refuse de démarrer en dessous)"
fi

# Demander confirmation si la config existe déjà
if [ -d "$NVIM_CONFIG_DIR" ] || [ -d "$LAZY_DIR" ]; then
    echo -e "\n${YELLOW}Attention:${NC} Une configuration Neovim existe déjà"
    echo -e "Config: $NVIM_CONFIG_DIR"
    echo -e "Plugins: $LAZY_DIR"
    echo -e "\n${YELLOW}Voulez-vous créer une sauvegarde? (o/N)${NC}"
    read -r response

    if [[ "$response" =~ ^[OoYy]$ ]]; then
        BACKUP_DIR="$HOME/nvim-backup-$(date +%Y%m%d-%H%M%S)"
        echo -e "${BLUE}→${NC} Sauvegarde dans: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"

        if [ -d "$NVIM_CONFIG_DIR" ]; then
            cp -r "$NVIM_CONFIG_DIR" "$BACKUP_DIR/config"
        fi
        if [ -d "$LAZY_DIR" ]; then
            cp -r "$LAZY_DIR" "$BACKUP_DIR/lazy"
        fi

        echo -e "${GREEN}✓${NC} Sauvegarde créée"
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
        cp -r "$plugin_dir" "$LAZY_DIR/"
    fi
done
echo -e "${GREEN}✓${NC} Plugins installés"

echo -e "\n${GREEN}[3/5]${NC} Installation des parsers Treesitter (branche main)..."
if [ -d "treesitter-parsers" ]; then
    SITE_PARSER_DIR="$NVIM_DATA_DIR/site/parser"
    mkdir -p "$SITE_PARSER_DIR"
    cp treesitter-parsers/*.so "$SITE_PARSER_DIR/"
    PARSER_COUNT=$(ls -1 "$SITE_PARSER_DIR"/*.so 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}✓${NC} $PARSER_COUNT parsers Treesitter installés (offline)"
else
    echo -e "${YELLOW}⚠${NC} Pas de parsers inclus. Ils seront compilés au premier lancement"
    echo -e "  (nécessite le CLI tree-sitter et un compilateur C)."
fi

echo -e "\n${GREEN}[4/5]${NC} Installation de la chaîne Java..."
for java_component in jdtls java-debug java-test; do
    if [ -d "$java_component" ]; then
        # cp -R src dest copierait dans dest s'il existe déjà : on vise le contenu
        mkdir -p "$HOME/.local/share/$java_component"
        cp -R "$java_component/." "$HOME/.local/share/$java_component/"
        echo -e "${GREEN}✓${NC} $java_component installé dans $HOME/.local/share/$java_component"
    else
        echo -e "${YELLOW}⚠${NC} $java_component non inclus dans ce bundle."
    fi
done

echo -e "\n${GREEN}[5/5]${NC} Vérification du binaire blink.cmp..."
if ls "$LAZY_DIR"/blink.cmp/target/release/libblink_cmp_fuzzy.* &> /dev/null; then
    echo -e "${GREEN}✓${NC} Binaire fuzzy blink.cmp présent"
else
    echo -e "${YELLOW}⚠${NC} Binaire blink.cmp absent : la complétion nécessitera cargo pour compiler."
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Installation terminée !${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${GREEN}Lancez Neovim maintenant:${NC} ${BLUE}nvim${NC}"
echo -e "Plugins, coloration et complétion fonctionnent déjà — rien à télécharger."
echo -e "\n${YELLOW}À compléter au besoin (voir DEPENDENCIES.md):${NC}"
echo -e "- ripgrep (rg)  → grep du picker Snacks (<leader>g)"
echo -e "- fd            → recherche de fichiers, plus rapide"
echo -e "- JDK 21+       → requis par jdtls (le serveur est là, pas la JVM)"
echo -e "- lazygit       → <leader>lg"
echo -e "- serveurs LSP  → paquets npm ordinaires"
INSTALL_SCRIPT

chmod +x "$EXPORT_DIR/install.sh"

# Créer la documentation des dépendances
cat > "$EXPORT_DIR/DEPENDENCIES.md" << 'DEPS_DOC'
# Dépendances système

Aucune n'est nécessaire pour démarrer : le bundle est autonome. Elles ajoutent
la recherche, le support Java et les serveurs LSP.

Sur une machine sans accès Internet mais disposant d'un miroir de paquets, les
commandes ci-dessous fonctionnent telles quelles une fois le miroir configuré :
ce sont des paquets système et npm ordinaires.

## Installation selon votre système

### Ubuntu/Debian
```bash
# Outils essentiels
sudo apt update
sudo apt install -y ripgrep fd-find git curl

# Node.js (>= 18) pour les LSP installés via npm
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Python
sudo apt install -y python3 python3-pip

# LSP servers (optionnel, peut être fait après)
npm install -g pyright bash-language-server typescript typescript-language-server svelte-language-server
```

### Fedora/RHEL
```bash
sudo dnf install -y ripgrep fd-find git curl nodejs python3 python3-pip
```

### Arch Linux
```bash
sudo pacman -S ripgrep fd git curl nodejs npm python python-pip
```

### macOS
```bash
brew install ripgrep fd git curl node python3
brew install lazygit  # optionnel (<leader>lg)
```

## Dépendances détaillées

### Essentielles
- **Neovim >= 0.12** — plancher dur, pas une recommandation : nvim-treesitter
  branche main refuse de démarrer en dessous. Si un `nvim-linux-*.tar.gz`
  accompagne ce bundle, install.sh s'en charge et il n'y a rien à faire.
- **git** - pour vim-fugitive et les indicateurs Git

### Optionnelles
- **ripgrep (rg)** - grep du picker Snacks (`<leader>g`)
- **fd** - recherche de fichiers (Snacks a un repli interne plus lent)
- **lazygit** - interface Git dans Neovim (`<leader>lg`)
- **JDK 21+** - requis par jdtls ; le bundle embarque le serveur, pas la JVM
- **Node.js >= 18** - pour les LSP installés via npm
- **Python 3** - pour les outils Python

### NON requises en offline (déjà incluses dans ce package)
- ~~tree-sitter CLI~~ et ~~compilateur C~~ - les parsers pré-compilés sont inclus
- ~~cargo~~ - le binaire fuzzy de blink.cmp est inclus
- ~~réseau~~ - lazy.nvim ne clone rien, les plugins sont posés tels quels
- ~~jdtls, java-debug, java-test~~ - embarqués, faute d'être distribués en
  paquet système ou en npm

### Formatters (optionnels, utilisés par conform.nvim)
```bash
# Lua
brew install stylua            # macOS
cargo install stylua           # ou via cargo

# Python
pip3 install ruff              # ruff_fix + ruff_format

# JavaScript/TypeScript/HTML/CSS/JSON/YAML/Markdown
npm install -g prettier

# XML
sudo apt install libxml2-utils # xmllint (Debian/Ubuntu)
brew install libxml2           # xmllint (macOS)
```

### LSP Servers (optionnels, pour autocomplétion et diagnostics)
```bash
# Lua (complétion de la config Neovim elle-même)
brew install lua-language-server          # macOS

# Python
npm install -g pyright
pip3 install ruff

# Bash
npm install -g bash-language-server

# JavaScript/TypeScript
npm install -g typescript typescript-language-server

# Svelte
npm install -g svelte-language-server

# Rust (si rust est installé)
rustup component add rust-analyzer
```

## Vérification de l'installation

```bash
nvim --version | head -1          # doit afficher v0.12 ou plus
command -v git && echo "✓ Git OK"
command -v rg && echo "✓ Ripgrep OK"
command -v fd && echo "✓ fd OK"
command -v lazygit && echo "✓ lazygit OK (optionnel)"
java -version 2>&1 | head -1      # 21+ requis par jdtls

# Formatters
command -v stylua && echo "✓ StyLua OK"
command -v prettier && echo "✓ Prettier OK"
command -v ruff && echo "✓ Ruff OK"
command -v xmllint && echo "✓ xmllint OK"

# LSP
command -v lua-language-server && echo "✓ lua_ls OK"
command -v pyright && echo "✓ Pyright OK"
command -v typescript-language-server && echo "✓ TypeScript LSP OK"
```

## Notes importantes

### Treesitter
✅ **Les parsers Treesitter sont inclus dans ce package** (branche `main` de
nvim-treesitter). Liste exacte : `ls treesitter-parsers/`.

Ce sont des binaires **compilés pour la plateforme inscrite dans `PLATFORM`**.
`install.sh` la vérifie et refuse une machine différente : sans réseau, la
seule issue est de régénérer le bundle sur la bonne plateforme
(`scripts/export-offline-linux.sh` dans le dépôt).
DEPS_DOC

# Créer le README
cat > "$EXPORT_DIR/README.md" << 'README'
# Configuration Neovim - Package Offline

Ce package contient une configuration complète de Neovim avec tous les plugins
nécessaires pour une installation offline.

## Contenu

- `config/` - Fichiers de configuration (init.lua, lazy-lock.json)
- `plugins/` - Tous les plugins tels qu'installés (binaire blink.cmp inclus)
- `treesitter-parsers/` - Parsers Treesitter pré-compilés (branche main)
- `jdtls/`, `java-debug/`, `java-test/` - Chaîne Java (absents si la machine
  d'export ne les avait pas)
- `nvim-linux-*.tar.gz` - Runtime Neovim 0.12+ (si embarqué à l'export)
- `PLATFORM` - Plateforme de build ; `install.sh` refuse une cible différente
- `install.sh` - Script d'installation automatique
- `DEPENDENCIES.md` - Liste complète des dépendances système

## Installation rapide

1. **Transférez ce dossier** sur la machine cible (clé USB, réseau, etc.)

   ⚠️ Le bundle contient des binaires natifs : il ne vaut que pour la
   plateforme inscrite dans le fichier `PLATFORM`. `install.sh` compare et
   refuse une machine différente plutôt que de laisser découvrir la panne à
   l'usage. Pour une autre cible, régénérez le bundle avec
   `scripts/export-offline-linux.sh` depuis le dépôt.

2. **Lancez l'installation**:
   ```bash
   cd nvim-config-offline
   chmod +x install.sh
   ./install.sh
   ```

   Rien n'est écrit hors de votre `$HOME` : ni droits root, ni gestionnaire de
   paquets. Si un `nvim-linux-*.tar.gz` accompagne ce bundle, Neovim est
   installé au passage dans `~/.local/share/neovim` (lié depuis
   `~/.local/bin`) — vérifiez alors que `~/.local/bin` est dans votre `PATH`.

3. **Lancez Neovim**:
   ```bash
   nvim
   ```

4. **Complétez à votre rythme** (voir DEPENDENCIES.md) : ripgrep pour la
   recherche, un JDK 21+ pour Java, les serveurs LSP et formatters. Rien de
   tout cela n'est nécessaire au démarrage — l'éditeur, les plugins, la
   coloration et la complétion fonctionnent dès l'étape 3.

## Structure de l'installation

```
~/.config/nvim/              # Configuration
  └── init.lua               # Fichier de config principal

~/.local/share/nvim/
  ├── lazy/                  # Plugins (dont lazy.nvim)
  │   ├── gruvbox.nvim/      # Colorscheme
  │   ├── snacks.nvim/       # Picker, explorer, indent, lazygit
  │   ├── blink.cmp/         # Complétion (binaire fuzzy inclus)
  │   └── ...                # Autres plugins
  └── site/parser/           # Parsers Treesitter pré-compilés

~/.local/share/neovim/       # Runtime Neovim (si embarqué dans le bundle)
~/.local/bin/nvim            # → lien vers le runtime ci-dessus
~/.local/share/jdtls/        # Serveur LSP Java
~/.local/share/java-debug/   # Adaptateur de debug Java (nvim-dap)
~/.local/share/java-test/    # Lanceur de tests Java
```

Rien en dehors de `$HOME` : l'installation ne demande pas de droits root et ne
touche pas au gestionnaire de paquets du système.

## Fonctionnalités

### Plugins inclus
- **gruvbox.nvim** (ellisonleao) - Colorscheme
- **snacks.nvim** - Picker (fuzzy finder), explorateur, indent guides, lazygit
- **blink.cmp** - Autocomplétion (snippets intégrés, binaire précompilé inclus)
- **nvim-treesitter** (branche main) - Coloration syntaxique moderne
- **leap.nvim** - Navigation rapide (`s` / `S`)
- **tiny-inline-diagnostic** - Diagnostics inline discrets
- **bufferline** + **lualine** - Onglets de buffers et statusline
- **fugitive** + **gitsigns** - Intégration Git
- **conform** - Formatage (stylua, ruff, prettier, xmllint)
- **which-key** - Aide sur les raccourcis
- **nvim-lspconfig** + **nvim-jdtls** - LSP (dont Java)

### Raccourcis principaux
- `<Space>` - Leader key
- `<F9>` - Toggle explorateur de fichiers
- `<Space><Tab>` - Révéler le fichier dans l'explorer / y revenir
- `<C-p>` - Find files
- `<Space>g` - Live grep
- `<F12>` / `<Space>b` - Liste des buffers
- `<Space>lg` - LazyGit
- `<Space>f` - Format code
- `s` + 2 caractères - Leap (saut rapide)
- `gcc` / `gc` - Commenter (natif)
- `gd` - Go to definition
- `H` - Show hover documentation

## Dépannage

### "Erreur: bundle construit pour X, machine Y"
Le bundle vient d'une autre plateforme, ses binaires sont inutilisables ici.
Régénérez-le depuis le dépôt avec `scripts/export-offline-linux.sh`. Pour
installer quand même la partie portable (config + plugins Lua) et vous passer
de Treesitter, du fuzzy blink et du runtime embarqué : `rm PLATFORM`.

### "nvim: command not found" après l'installation
Le runtime embarqué est lié depuis `~/.local/bin`, absent du `PATH` par défaut
sur certaines distributions :
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && exec bash
```

### "lazy.nvim not found"
```bash
ls ~/.local/share/nvim/lazy/lazy.nvim
```

### "rg command not found"
Le picker (`<leader>g`) a besoin de ripgrep — voir DEPENDENCIES.md. Le reste de
l'éditeur fonctionne sans.

### Pas de coloration syntaxique / erreurs treesitter
```bash
ls ~/.local/share/nvim/site/parser/   # doit lister des .so
nvim --headless -c 'checkhealth nvim-treesitter' -c 'qa'
```
Un dossier vide signifie que la machine d'export n'avait pas compilé ses
parsers. Sans réseau, seul un nouveau bundle corrige cela.

### La complétion ne fonctionne pas
Vérifiez le binaire fuzzy de blink.cmp :
```bash
ls ~/.local/share/nvim/lazy/blink.cmp/target/release/
```
Absent, blink retombe sur son implémentation Lua : la complétion marche, le
classement des résultats est simplement moins bon.

### Java : rien ne démarre sur un fichier .java
jdtls exige un JDK 21+ sur la machine (le bundle embarque le serveur, pas la
JVM) :
```bash
java -version
ls ~/.local/share/jdtls/plugins/org.eclipse.equinox.launcher_*.jar
```

### Les LSP ne fonctionnent pas
Installez les serveurs LSP nécessaires (voir DEPENDENCIES.md). Ils ne sont pas
embarqués : ce sont des paquets npm ordinaires, disponibles partout où un
registre npm est joignable.

## Support

- `:help` dans Neovim
- `:checkhealth` pour diagnostiquer les problèmes
README

# Créer l'archive
echo -e "\n${GREEN}Création de l'archive...${NC}"
# -C : sans ça, le chemin absolu de EXPORT_DIR serait gravé dans l'archive.
tar -czf "$ARCHIVE" -C "$DIST_DIR" "$(basename "$EXPORT_DIR")"

# Afficher les résultats
ARCHIVE_SIZE=$(du -h "$ARCHIVE" | cut -f1)
DIR_SIZE=$(du -sh "$EXPORT_DIR" | cut -f1)

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Export terminé avec succès !${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${BLUE}Fichiers créés:${NC}"
echo -e "  Archive:  ${GREEN}${ARCHIVE#"$REPO_DIR"/}${NC} ($ARCHIVE_SIZE)"
echo -e "  Dossier:  ${GREEN}${EXPORT_DIR#"$REPO_DIR"/}/${NC} ($DIR_SIZE)"

echo -e "\n${BLUE}Contenu:${NC}"
echo -e "  • Configuration Neovim (init.lua, lazy-lock.json)"
echo -e "  • $PLUGIN_COUNT plugins (dont binaire blink.cmp précompilé)"
if [ -d "$TREESITTER_PARSER_DEST" ]; then
    PARSER_COUNT=$(ls -1 "$TREESITTER_PARSER_DEST"/*.so 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  • ${GREEN}$PARSER_COUNT parsers Treesitter pré-compilés${NC}"
fi
for java_component in jdtls java-debug java-test; do
    if [ -d "$EXPORT_DIR/$java_component" ]; then
        echo -e "  • ${GREEN}Java : $java_component${NC}"
    fi
done
if ls "$EXPORT_DIR"/nvim-linux-*.tar.gz &>/dev/null; then
    echo -e "  • ${GREEN}Runtime Neovim embarqué${NC}"
fi
echo -e "  • Plateforme cible : ${GREEN}$(cat "$EXPORT_DIR/PLATFORM")${NC}"
echo -e "  • Script d'installation (install.sh)"
echo -e "  • Documentation des dépendances (DEPENDENCIES.md)"
echo -e "  • README"

echo -e "\n${BLUE}Pour transférer sur la machine offline:${NC}"
echo -e "  1. Copiez ${GREEN}nvim-config-offline.tar.gz${NC} (clé USB, réseau, etc.)"
echo -e "  2. Décompressez: ${BLUE}tar -xzf nvim-config-offline.tar.gz${NC}"
echo -e "  3. Installez: ${BLUE}cd nvim-config-offline && ./install.sh${NC}"
echo -e "\n${YELLOW}⚠ Binaires compilés pour cette machine : cible = même architecture/OS${NC}"
echo -e "${YELLOW}N'oubliez pas d'installer les dépendances système (voir DEPENDENCIES.md)${NC}\n"
