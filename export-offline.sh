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

EXPORT_DIR="nvim-config-offline"
PLUGINS_DIR="$EXPORT_DIR/plugins"
LAZY_DIR="$HOME/.local/share/nvim/lazy"
PARSER_DIR="$HOME/.local/share/nvim/site/parser"

if [ ! -d "$LAZY_DIR" ]; then
    echo -e "${RED}Erreur: $LAZY_DIR introuvable. Lancez Neovim une fois d'abord.${NC}"
    exit 1
fi

# Créer le dossier d'export
echo -e "${GREEN}[1/4]${NC} Création de la structure d'export..."
rm -rf "$EXPORT_DIR"
mkdir -p "$PLUGINS_DIR"
mkdir -p "$EXPORT_DIR/config"

# Copier les fichiers de configuration
echo -e "${GREEN}[2/4]${NC} Copie des fichiers de configuration..."
cp init.lua "$EXPORT_DIR/config/"
if [ -f "lazy-lock.json" ]; then
    cp lazy-lock.json "$EXPORT_DIR/config/"
fi

# Copier les plugins tels qu'installés (inclut le binaire précompilé de blink.cmp)
echo -e "\n${GREEN}[3/4]${NC} Copie des plugins installés..."
cp -R "$LAZY_DIR/." "$PLUGINS_DIR/"
PLUGIN_COUNT=$(ls -1 "$PLUGINS_DIR" | wc -l | tr -d ' ')
echo -e "${GREEN}✓${NC} $PLUGIN_COUNT plugins copiés"

# Nettoyer les dossiers .git pour économiser de l'espace
find "$PLUGINS_DIR" -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true

# Copier les parsers Treesitter pré-compilés (branche main : site/parser)
echo -e "\n${GREEN}[4/4]${NC} Copie des parsers Treesitter..."
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

# Vérifier que Neovim est installé
if ! command -v nvim &> /dev/null; then
    echo -e "${RED}Erreur: Neovim n'est pas installé${NC}"
    echo -e "Installez Neovim >= 0.12 avant de continuer"
    exit 1
fi

NVIM_VERSION=$(nvim --version | head -n1 | grep -oE 'v[0-9]+\.[0-9]+' || echo "v0.0")
echo -e "${BLUE}→${NC} Neovim version: $NVIM_VERSION"
if [ "$(echo "$NVIM_VERSION" | grep -oE '[0-9]+$')" -lt 12 ]; then
    echo -e "${YELLOW}Attention:${NC} cette configuration requiert Neovim >= 0.12"
    echo -e "(vim.lsp.config, nvim-treesitter branche main)"
fi

# Chemins
NVIM_CONFIG_DIR="$HOME/.config/nvim"
NVIM_DATA_DIR="$HOME/.local/share/nvim"
LAZY_DIR="$NVIM_DATA_DIR/lazy"

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
echo -e "\n${GREEN}[1/4]${NC} Installation de la configuration..."
mkdir -p "$NVIM_CONFIG_DIR"
cp config/init.lua "$NVIM_CONFIG_DIR/"
if [ -f "config/lazy-lock.json" ]; then
    cp config/lazy-lock.json "$NVIM_CONFIG_DIR/"
fi
echo -e "${GREEN}✓${NC} Configuration copiée"

echo -e "\n${GREEN}[2/4]${NC} Installation des plugins (dont lazy.nvim)..."
mkdir -p "$LAZY_DIR"
for plugin_dir in plugins/*; do
    if [ -d "$plugin_dir" ]; then
        echo -e "${BLUE}→${NC} $(basename "$plugin_dir")"
        cp -r "$plugin_dir" "$LAZY_DIR/"
    fi
done
echo -e "${GREEN}✓${NC} Plugins installés"

echo -e "\n${GREEN}[3/4]${NC} Installation des parsers Treesitter (branche main)..."
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

echo -e "\n${GREEN}[4/4]${NC} Vérification du binaire blink.cmp..."
if ls "$LAZY_DIR"/blink.cmp/target/release/libblink_cmp_fuzzy.* &> /dev/null; then
    echo -e "${GREEN}✓${NC} Binaire fuzzy blink.cmp présent"
else
    echo -e "${YELLOW}⚠${NC} Binaire blink.cmp absent : la complétion nécessitera cargo pour compiler."
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Installation terminée !${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${YELLOW}Notes importantes:${NC}"
echo -e "1. Installez les dépendances système (voir DEPENDENCIES.md)"
echo -e "2. Lancez Neovim: ${BLUE}nvim${NC}"
echo -e "3. ${GREEN}Tout est installé offline${NC} (plugins + binaire blink + parsers)"
echo -e "\n${YELLOW}Dépendances système minimales:${NC}"
echo -e "- ripgrep (rg) - pour le grep du picker Snacks"
echo -e "- fd - pour la recherche de fichiers (optionnel mais recommandé)"
echo -e "- lazygit - pour <leader>lg (optionnel)"
INSTALL_SCRIPT

chmod +x "$EXPORT_DIR/install.sh"

# Créer la documentation des dépendances
cat > "$EXPORT_DIR/DEPENDENCIES.md" << 'DEPS_DOC'
# Dépendances système

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
- **Neovim >= 0.12** (vim.lsp.config, nvim-treesitter branche main)
- **git** - pour lazy.nvim
- **ripgrep (rg)** - pour le grep du picker Snacks
- **fd** - pour la recherche de fichiers (optionnel mais recommandé)

### Optionnelles
- **lazygit** - interface Git dans Neovim (`<leader>lg`)
- **Node.js >= 18** - pour les LSP installés via npm
- **Python 3 + pip** - pour les LSP/linters Python

### NON requises en offline (déjà incluses dans ce package)
- ~~tree-sitter CLI~~ - les parsers pré-compilés sont inclus
- ~~cargo~~ - le binaire fuzzy de blink.cmp est inclus

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
command -v nvim && echo "✓ Neovim OK"
command -v git && echo "✓ Git OK"
command -v rg && echo "✓ Ripgrep OK"
command -v fd && echo "✓ fd OK"
command -v lazygit && echo "✓ lazygit OK (optionnel)"

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
✅ **Les parsers Treesitter sont inclus dans ce package !**

Parsers pré-compilés (branche `main` de nvim-treesitter) : lua, vim, vimdoc,
javascript, typescript, html, css, python, java, bash, json, yaml, toml, xml,
markdown, markdown_inline, rust, svelte, vue, regex.

⚠️ Ce sont des binaires **compilés pour l'architecture de la machine d'export** :
la machine cible doit avoir la même architecture/OS. Sinon, supprimez
`treesitter-parsers/` et laissez Neovim recompiler (requiert tree-sitter CLI
et un compilateur C sur la cible).
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
- `install.sh` - Script d'installation automatique
- `DEPENDENCIES.md` - Liste complète des dépendances système

## Installation rapide

1. **Transférez ce dossier** sur la machine cible (clé USB, réseau, etc.)
   ⚠️ Même architecture/OS requis (binaires pré-compilés)

2. **Installez les dépendances système** (voir DEPENDENCIES.md)
   Minimum requis: Neovim >= 0.12, git, ripgrep

3. **Lancez l'installation**:
   ```bash
   cd nvim-config-offline
   chmod +x install.sh
   ./install.sh
   ```

4. **Lancez Neovim**:
   ```bash
   nvim
   ```

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
```

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

### "lazy.nvim not found"
```bash
ls ~/.local/share/nvim/lazy/lazy.nvim
```

### "rg command not found"
```bash
sudo apt install ripgrep  # Ubuntu/Debian
brew install ripgrep      # macOS
```

### Pas de coloration syntaxique / erreurs treesitter
Les parsers inclus sont compilés pour l'architecture de la machine d'export.
Si la cible est différente : supprimez `~/.local/share/nvim/site/parser/`,
installez le CLI tree-sitter, puis relancez Neovim (recompilation automatique).

### La complétion ne fonctionne pas
Vérifiez le binaire blink.cmp :
```bash
ls ~/.local/share/nvim/lazy/blink.cmp/target/release/
```
S'il est absent (architecture différente), il faut cargo pour recompiler.

### Les LSP ne fonctionnent pas
Installez les serveurs LSP nécessaires (voir DEPENDENCIES.md).

## Support

- `:help` dans Neovim
- `:checkhealth` pour diagnostiquer les problèmes
README

# Créer l'archive
echo -e "\n${GREEN}Création de l'archive...${NC}"
tar -czf nvim-config-offline.tar.gz "$EXPORT_DIR"

# Afficher les résultats
ARCHIVE_SIZE=$(du -h nvim-config-offline.tar.gz | cut -f1)
DIR_SIZE=$(du -sh "$EXPORT_DIR" | cut -f1)

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Export terminé avec succès !${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${BLUE}Fichiers créés:${NC}"
echo -e "  Archive:  ${GREEN}nvim-config-offline.tar.gz${NC} ($ARCHIVE_SIZE)"
echo -e "  Dossier:  ${GREEN}$EXPORT_DIR/${NC} ($DIR_SIZE)"

echo -e "\n${BLUE}Contenu:${NC}"
echo -e "  • Configuration Neovim (init.lua, lazy-lock.json)"
echo -e "  • $PLUGIN_COUNT plugins (dont binaire blink.cmp précompilé)"
if [ -d "$TREESITTER_PARSER_DEST" ]; then
    PARSER_COUNT=$(ls -1 "$TREESITTER_PARSER_DEST"/*.so 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  • ${GREEN}$PARSER_COUNT parsers Treesitter pré-compilés${NC}"
fi
echo -e "  • Script d'installation (install.sh)"
echo -e "  • Documentation des dépendances (DEPENDENCIES.md)"
echo -e "  • README"

echo -e "\n${BLUE}Pour transférer sur la machine offline:${NC}"
echo -e "  1. Copiez ${GREEN}nvim-config-offline.tar.gz${NC} (clé USB, réseau, etc.)"
echo -e "  2. Décompressez: ${BLUE}tar -xzf nvim-config-offline.tar.gz${NC}"
echo -e "  3. Installez: ${BLUE}cd nvim-config-offline && ./install.sh${NC}"
echo -e "\n${YELLOW}⚠ Binaires compilés pour cette machine : cible = même architecture/OS${NC}"
echo -e "${YELLOW}N'oubliez pas d'installer les dépendances système (voir DEPENDENCIES.md)${NC}\n"
