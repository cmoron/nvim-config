# Configuration Neovim Minimale

Configuration Neovim personnelle basée sur la configuration Vim précédente, adaptée pour Neovim 0.11+.

## Prérequis

### Version Neovim
- **Neovim >= 0.11** (pour l'API LSP native)

Vérifier la version :
```bash
nvim --version
```

### Dépendances système

#### Installation groupée (Ubuntu/Debian)
```bash
# Installer toutes les dépendances de base
sudo apt update
sudo apt install -y git curl wget unzip ripgrep build-essential python3 python3-pip
```

#### Détail des dépendances

##### 1. Outils de base
```bash
sudo apt install git curl wget unzip
```
- **git** : Gestion des plugins et vim-fugitive
- **curl/wget** : Téléchargement de ressources
- **unzip** : Extraction des archives (fonts, plugins)

##### 2. Ripgrep (pour Telescope live grep)
```bash
sudo apt install ripgrep

# Vérification
rg --version
```

##### 3. Build tools (pour compiler Treesitter et autres plugins)
```bash
sudo apt install build-essential
```
Inclut : gcc, g++, make

##### 4. Python et Pip (pour les serveurs LSP Python)
```bash
sudo apt install python3 python3-pip

# Vérification
python3 --version
pip3 --version
```

##### 5. Node.js et npm (pour Copilot et serveurs LSP)
```bash
# Requis : Node.js >= 18
# Installation via nvm (recommandé) ou apt

# Vérification
node --version
npm --version
```

### Formatters (optionnel, pour conform.nvim)

Ces formatters sont utilisés par conform.nvim pour formater votre code avec `<leader>f`.

#### Prettier (JavaScript, TypeScript, HTML, CSS, JSON, etc.)
```bash
npm install -g prettier
```

#### Black (Python)
```bash
pip install black
```

#### StyLua (Lua)
```bash
cargo install stylua
# ou télécharger depuis https://github.com/JohnnyMorganz/StyLua/releases
```

> **Note :** Si un formatter n'est pas installé, conform.nvim utilisera le LSP comme fallback.

### Fonts

#### Hack Nerd Font (pour les icônes)

**Sous WSL2 :**
1. Installer côté Windows : télécharger depuis https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
2. Extraire et installer les fichiers `.ttf` (clic droit > Installer pour tous les utilisateurs)
3. Configurer Windows Terminal : Paramètres > Profil Ubuntu > Apparence > Police > "Hack Nerd Font Mono"

**Sous Linux natif :**
```bash
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
unzip Hack.zip
rm Hack.zip
fc-cache -fv
```

Puis configurer votre terminal pour utiliser "Hack Nerd Font Mono".

## Serveurs LSP

Les serveurs LSP fournissent l'autocomplétion, le go-to-definition, les diagnostics, etc.

### Python - Pyright
```bash
pip install pyright
# ou
npm install -g pyright
```

### Bash - bash-language-server
```bash
npm install -g bash-language-server
```

### JavaScript/TypeScript - typescript-language-server
```bash
npm install -g typescript-language-server typescript
```

### Svelte - svelte-language-server
```bash
npm install -g svelte-language-server
```

### Rust - rust-analyzer
```bash
# Via rustup (si Rust est installé)
rustup component add rust-analyzer
```

### Vérification des LSP installés
```bash
# Python
which pyright-langserver

# Bash
which bash-language-server

# JavaScript/TypeScript
which typescript-language-server

# Svelte
which svelteserver

# Rust
which rust-analyzer
```

## Installation

1. Cloner ou copier cette configuration dans `~/.config/nvim/`
2. Installer les dépendances listées ci-dessus
3. Lancer Neovim : `nvim`
4. Les plugins s'installeront automatiquement au premier démarrage (via lazy.nvim)
5. Redémarrer Neovim après l'installation des plugins

## Raccourcis - Vue d'ensemble complète

**Leader key** : `Espace`

### 🗂️ Navigation et Fichiers (Telescope)

| Raccourci | Description |
|-----------|-------------|
| `F9` | Toggle NvimTree (explorateur de fichiers) |
| `<leader><Tab>` | Trouver le fichier courant dans NvimTree |
| `Ctrl-P` | Recherche de fichiers (Telescope find_files) |
| `<leader>p` | Liste des buffers (Telescope buffers) |
| `<leader>g` | Recherche de texte dans tous les fichiers (Telescope live_grep) |
| `<leader>fh` | Recherche dans l'aide (Telescope help_tags) |
| `<leader>fd` | Liste des diagnostics (Telescope diagnostics) |
| `<leader>fr` | Références LSP (Telescope lsp_references) |
| `<leader>fs` | Symboles du document (Telescope lsp_document_symbols) |

**Dans Telescope :**
- `Ctrl-j` / `Ctrl-k` - Naviguer dans les résultats
- `Enter` - Ouvrir le fichier
- `Esc` - Fermer Telescope

**Filtres actifs :**
Telescope ignore automatiquement :
- `.git/` - Dossier git
- `node_modules/` - Dépendances Node.js
- `build/`, `dist/`, `target/` - Dossiers de build
- `__pycache__/`, `*.pyc` - Cache Python
- `*.lock` - Fichiers lock
- `*.min.js`, `*.min.css` - Fichiers minifiés
### 📑 Gestion des Buffers

| Raccourci | Description |
|-----------|-------------|
| `Tab` | Buffer suivant |
| `Shift-Tab` | Buffer précédent |
| `F12` | Ouvrir BufExplorer (liste complète des buffers) |
| `<leader>b` | BufExplorer (raccourci alternatif) |

**Dans BufExplorer :**
- `d` - Supprimer un buffer
- `s` - Trier (nom, MRU, extension)
- `Enter` - Ouvrir le buffer
- `q` - Quitter

### 🎯 Navigation Rapide (Harpoon)

Harpoon permet de marquer vos fichiers favoris et de naviguer rapidement entre eux.

| Raccourci | Description |
|-----------|-------------|
| `<leader>a` | Ajouter le fichier actuel à Harpoon |
| `<leader>h` | Ouvrir le menu Harpoon |
| `<leader>1` à `<leader>4` | Aller directement au fichier 1-4 |
| `Ctrl-Shift-P` | Fichier Harpoon précédent |
| `Ctrl-Shift-N` | Fichier Harpoon suivant |

**Workflow typique :**
1. Ouvrir vos 3-4 fichiers principaux
2. Marquer chacun avec `<leader>a`
3. Naviguer instantanément avec `<leader>1`, `<leader>2`, etc.

### ⌨️ Autocomplétion (nvim-cmp)

L'autocomplétion se déclenche **manuellement** avec `Ctrl-Space` et affiche un popup avec :
- ✅ Suggestions LSP (fonctions, variables, méthodes) avec documentation complète
- ✅ Mots du buffer actuel
- ✅ Chemins de fichiers

**Dans le popup d'autocomplétion :**

| Raccourci | Description |
|-----------|-------------|
| `Tab` | Sélectionner l'élément suivant |
| `Shift-Tab` | Sélectionner l'élément précédent |
| `Enter` | Confirmer la sélection |
| `Ctrl-e` | Fermer le popup |
| `Ctrl-Space` | Forcer l'affichage du popup |
| `Ctrl-f` | Scroller la documentation vers le bas |
| `Ctrl-b` | Scroller la documentation vers le haut |

> **Note :** GitHub Copilot fonctionne en parallèle et affiche ses suggestions en gris (inchangé).

### 🔧 LSP - Navigation et Actions

**Ces raccourcis fonctionnent quand un serveur LSP est actif** (Python, Bash, JavaScript/TypeScript, Svelte, Rust)

#### Navigation dans le Code

| Raccourci | Description |
|-----------|-------------|
| `gd` | Go to Definition (aller à la définition) |
| `gD` | Go to Declaration (aller à la déclaration) |
| `grr` | Find References (trouver toutes les références) |
| `gri` | Go to Implementation (aller à l'implémentation) |
| `gO` | Document symbols (plan/outline du fichier) |

#### Documentation

| Raccourci | Description |
|-----------|-------------|
| `H` | Hover - Afficher la documentation de l'élément sous le curseur |

#### Diagnostics (Erreurs/Warnings)

| Raccourci | Description |
|-----------|-------------|
| `<leader>n` | Aller au diagnostic suivant |
| `<leader>N` | Aller au diagnostic précédent |
| `<leader>e` | Afficher l'erreur détaillée en fenêtre flottante |

#### Actions de Code

| Raccourci | Description |
|-----------|-------------|
| `grn` ou `<leader>rn` | Rename - Renommer le symbole sous le curseur |
| `gra` ou `<leader>ca` | Code Action - Actions de code disponibles |

### 🔍 Trouble (Diagnostics et Quickfix)

Interface moderne pour visualiser les diagnostics, erreurs et références.

| Raccourci | Description |
|-----------|-------------|
| `<leader>xx` | Toggle Trouble (tous les diagnostics) |
| `<leader>xd` | Diagnostics du document actuel |
| `<leader>xs` | Symboles du document |
| `<leader>xl` | Définitions/Références LSP |
| `<leader>xq` | Quickfix list |

### 💬 Commentaires

| Raccourci | Mode | Description |
|-----------|------|-------------|
| `<leader>c<leader>` | Normal/Visuel | Toggle commentaire (ligne ou sélection) |
| `gcc` | Normal | Toggle commentaire ligne courante |
| `gc` | Visuel | Toggle commentaire de la sélection |

### 🚀 Navigation Rapide (vim-sneak)

| Raccourci | Description |
|-----------|-------------|
| `s{char}{char}` | Chercher 2 caractères vers l'avant avec labels |
| `S{char}{char}` | Chercher 2 caractères vers l'arrière avec labels |

Après avoir tapé les 2 caractères, des labels apparaissent sur les correspondances.

### ✏️ Édition et Formatage

| Raccourci | Mode | Description |
|-----------|------|-------------|
| `<leader>f` | Normal | Formater le buffer (conform.nvim) |
| `Shift-Tab` | Insertion | Déindenter la ligne |
| `J` | Normal | Scroll rapide vers le bas (2 lignes) |
| `K` | Normal | Scroll rapide vers le haut (3 lignes) |

**Formatage avec conform.nvim :**
- Utilise prettier, black, stylua selon le type de fichier
- Fallback sur le formatage LSP si pas de formatter installé
- Voir la section "Formatters" pour installer les formatters

> **Note :** `K` est utilisé pour le scroll. Pour afficher la documentation LSP, utiliser `H`.

### 🔄 Configuration

| Raccourci | Description |
|-----------|-------------|
| `<leader><Enter>` | Recharger la configuration Neovim |

### 🔑 Which-key (Découverte des raccourcis)

**Which-key affiche automatiquement les raccourcis disponibles** quand vous tapez `<leader>`.

Exemple : Tapez `<leader>` et attendez 500ms → un popup apparaît avec tous les raccourcis possibles :
- `<leader>f...` - Find/Format
- `<leader>x...` - Trouble
- `<leader>c...` - Comment
- etc.

Très utile pour découvrir les raccourcis ou se rappeler des commandes !

### 🌿 Git (vim-fugitive)

**Commandes** (mode commande `:`) :

| Commande | Description |
|----------|-------------|
| `:Git` | Interface Git principale |
| `:Git status` | Statut Git |
| `:Git commit` | Commit |
| `:Git push` | Push vers le remote |
| `:Git pull` | Pull depuis le remote |
| `:Git diff` | Voir les différences |
| `:Git blame` | Voir le blame ligne par ligne |

**Indicateurs Git (gitsigns)** : Les modifications sont affichées dans la marge (colonne de signes)

---

## Résumé des touches de fonction

| Touche | Action |
|--------|--------|
| `F9` | Toggle NvimTree |
| `F12` | BufExplorer |

## Plugins installés

### Core
- **lazy.nvim** - Gestionnaire de plugins
- **gruvbox** - Colorscheme

### Navigation et Fichiers
- **nvim-tree** - Explorateur de fichiers
- **telescope.nvim** - Fuzzy finder moderne (fichiers, grep, LSP, etc.)
- **harpoon** - Navigation rapide entre fichiers favoris

### Buffers et UI
- **bufferline** - Affichage des buffers en onglets
- **bufexplorer** - Gestionnaire de buffers
- **lualine** - Barre de statut
- **which-key** - Affiche les raccourcis disponibles

### Git
- **gitsigns** - Indicateurs Git dans la marge
- **vim-fugitive** - Intégration Git complète

### Édition
- **Comment.nvim** - Commenter du code
- **nvim-autopairs** - Fermeture automatique des parenthèses/quotes
- **vim-sneak** - Navigation rapide par 2 caractères
- **conform.nvim** - Formatage de code (prettier, black, stylua, etc.)

### LSP et Complétion
- **nvim-cmp** - Moteur d'autocomplétion moderne
  - **cmp-nvim-lsp** - Source LSP
  - **cmp-buffer** - Source buffer
  - **cmp-path** - Source paths
- **nvim-lspconfig** - Configuration LSP
- **trouble.nvim** - Interface pour diagnostics et quickfix

### Visuel et Syntaxe
- **indent-blankline** - Guides d'indentation
- **nvim-colorizer** - Affichage des couleurs CSS
- **nvim-treesitter** - Parsing et coloration syntaxique avancée

### IA
- **copilot.vim** - GitHub Copilot

## Désactivation temporaire

### Copilot
Si vous ne voulez pas utiliser Copilot, commentez la ligne dans `init.lua` :
```lua
-- "github/copilot.vim",
```

### LSP spécifiques
Pour désactiver un LSP, commentez la ligne correspondante dans `init.lua` :
```lua
-- vim.lsp.enable('pyright')
-- vim.lsp.enable('ts_ls')
```

## Résolution de problèmes

### Les icônes ne s'affichent pas
→ Vérifiez que Hack Nerd Font est bien installée et sélectionnée dans votre terminal

### Le LSP ne démarre pas
→ Vérifiez que le serveur LSP est bien installé (voir section "Serveurs LSP")
→ Vérifiez avec `:lua print(vim.inspect(vim.lsp.get_clients()))`

### Warning au démarrage
→ Les warnings de deprecation sont filtrés automatiquement dans la config
→ Si vous voyez d'autres warnings, vérifiez `:checkhealth`

### Fichiers non rechargés automatiquement
→ Vérifiez que `autoread` est activé dans la config
→ Les fichiers sont rechargés au focus/changement de buffer

## Personnalisation

Tous les réglages sont dans `~/.config/nvim/init.lua`. Le fichier est bien commenté et organisé en sections :

1. Settings de base
2. Autocmds (indentation par filetype)
3. Mappings
4. Bootstrap lazy.nvim
5. Plugins (avec configurations détaillées)
6. Configuration LSP

### Modifier les filtres Telescope

Pour ajouter/retirer des patterns à ignorer, modifiez `file_ignore_patterns` dans la config Telescope (init.lua) :

```lua
file_ignore_patterns = {
    "^.git/",
    "node_modules/",
    -- Ajoutez vos patterns ici
    "mon_dossier/",
    "%.tmp$",
},
```

**Note :** Les patterns utilisent la syntaxe Lua :
- `^` = début de chemin
- `$` = fin de chemin
- `%.` = point littéral (échappé)
- `/` = slash littéral

N'hésitez pas à adapter selon vos besoins !
