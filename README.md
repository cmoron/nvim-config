# Configuration Neovim

Configuration Neovim personnelle, moderne et minimaliste (Neovim 0.12+).

Stack actuelle : **snacks.nvim** (picker, explorer, indent, lazygit), **blink.cmp** (complétion),
**nvim-treesitter** (branche `main`), **leap**, **tiny-inline-diagnostic**, **gruvbox**.

> **Versions :** le tag `v2.0.0` correspond à cette stack. Le tag `v1.0.0` pointe sur
> l'ancienne stack (Telescope, nvim-cmp, nvim-tree, harpoon…) si un retour arrière est nécessaire.

## Prérequis

### Version Neovim

- **Neovim >= 0.12** (vim.lsp.config natif, nvim-treesitter branche `main`)

```bash
# macOS
brew install neovim

# Ubuntu (snap, pour avoir la dernière stable)
sudo snap install nvim --classic

# Vérification
nvim --version
```

### Dépendances système

#### 1. Outils de base

```bash
# macOS
brew install git ripgrep fd lazygit tree-sitter-cli

# Ubuntu/Debian
sudo apt update
sudo apt install -y git curl ripgrep fd-find build-essential
```

- **git** : gestion des plugins et vim-fugitive
- **ripgrep** / **fd** : recherche du picker Snacks (grep / find files)
- **lazygit** : interface Git dans Neovim (`<leader>lg`) — optionnel
- **tree-sitter-cli** : compilation des parsers Treesitter (branche `main`)
- **build-essential** : compilateur C pour les parsers (Linux uniquement)

#### 2. Python (via uv)

Ne pas utiliser `pip` système. Installer **uv** :

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install ruff
```

#### 3. Node.js (v20 LTS)

```bash
# Ubuntu/Debian via NodeSource
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Outils JS/Bash/Lua en global
sudo npm install -g pyright prettier bash-language-server
```

#### 4. Rust (via rustup)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup component add rust-analyzer
cargo install stylua   # formatter Lua
```

### Formatters (pour conform.nvim)

Utilisés par conform.nvim via `<leader>f` :

| Langage                     | Formatter | Installé via                                         |
| --------------------------- | --------- | ---------------------------------------------------- |
| Python                      | Ruff      | `uv tool install ruff`                               |
| JS/TS/HTML/CSS/JSON/YAML/MD | Prettier  | `npm install -g prettier`                            |
| Lua                         | StyLua    | `cargo install stylua` / `brew install stylua`       |
| XML                         | xmllint   | `apt install libxml2-utils` / `brew install libxml2` |

> **Note :** si un formatter n'est pas installé, conform.nvim utilise le LSP en fallback.

### Fonts

#### Hack Nerd Font (pour les icônes)

**Sous macOS :**

```bash
brew install --cask font-hack-nerd-font
```

**Sous WSL2 :**

1. Télécharger https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip côté Windows
2. Extraire et installer les `.ttf` (clic droit > Installer pour tous les utilisateurs)
3. Windows Terminal : Paramètres > Profil > Apparence > Police > "Hack Nerd Font Mono"

**Sous Linux natif :**

```bash
mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
unzip Hack.zip && rm Hack.zip
fc-cache -fv
```

## Serveurs LSP

| Langage              | Serveur LSP                | Installé via                                                                   |
| -------------------- | -------------------------- | ------------------------------------------------------------------------------ |
| Lua                  | lua-language-server        | `brew install lua-language-server`                                             |
| Python               | Pyright                    | `npm install -g pyright`                                                       |
| Python (lint/format) | Ruff                       | `uv tool install ruff`                                                         |
| Bash                 | bash-language-server       | `npm install -g bash-language-server`                                          |
| JS/TS                | typescript-language-server | `npm install -g typescript-language-server typescript`                         |
| Svelte               | svelte-language-server     | `npm install -g svelte-language-server`                                        |
| Rust                 | rust-analyzer              | `rustup component add rust-analyzer`                                           |
| Go                   | gopls                      | `go install golang.org/x/tools/gopls@latest`                                   |
| Java                 | jdtls                      | `scripts/install.sh` (si JDK 21+ présent) ; le bundle offline l'embarque aussi |

### Vérification

```bash
which lua-language-server pyright bash-language-server typescript-language-server svelteserver rust-analyzer
```

## Installation

Cloner le dépôt où l'on veut, puis lancer le script :

```bash
gh repo clone cmoron/nvim-config   # ou git clone git@github.com:cmoron/nvim-config.git
cd nvim-config
./scripts/install.sh
```

`install.sh` crée le symlink `~/.config/nvim` → dépôt, installe les serveurs LSP
et formatters manquants, puis les plugins aux versions de `lazy-lock.json`. Le
dépôt reste à l'endroit choisi : toute modification y est active immédiatement.

Une config existante est sauvegardée en `~/.config/nvim.bak-<horodatage>`.

| Option            | Effet                                        |
| ----------------- | -------------------------------------------- |
| `-c`, `--check`   | Vérifie prérequis et outils, n'installe rien |
| `-n`, `--dry-run` | Affiche les actions sans les exécuter        |

### Installation offline

Le script `scripts/export-offline.sh` génère un bundle complet (plugins + binaire
blink.cmp + parsers Treesitter pré-compilés + serveur Java jdtls) transférable sur
une machine sans connexion :

```bash
scripts/export-offline.sh
# → dist/nvim-config-offline.tar.gz
```

⚠️ Les binaires sont compilés pour l'architecture de la machine d'export :
la cible doit avoir la même architecture/OS. Voir le README du bundle généré.

## Raccourcis - Vue d'ensemble complète

**Leader key** : `Espace`

### 🗂️ Navigation et Fichiers (Snacks picker + explorer)

| Raccourci       | Description                                                              |
| --------------- | ------------------------------------------------------------------------ |
| `F9`            | Toggle explorer de fichiers                                              |
| `<leader><Tab>` | Révéler le fichier courant dans l'explorer / y revenir depuis l'explorer |
| `Ctrl-P`        | Recherche de fichiers                                                    |
| `<leader>p`     | Liste des buffers                                                        |
| `<leader>g`     | Recherche de texte (live grep)                                           |
| `<leader>fh`    | Recherche dans l'aide                                                    |
| `<leader>fd`    | Liste des diagnostics                                                    |
| `<leader>fr`    | Références LSP                                                           |
| `<leader>fs`    | Symboles du document                                                     |

**Dans un picker :**

- `Ctrl-j` / `Ctrl-k` - Naviguer dans les résultats
- `Enter` - Ouvrir / `Esc` ou `q` - Fermer
- `/` - Basculer entre champ de recherche et liste

**Dans l'explorer :**

- `Enter` ou `l` - Ouvrir / déplier, `h` - replier, `<BS>` - dossier parent
- `a` nouveau fichier, `d` supprimer (corbeille), `r` renommer, `m`/`c` déplacer/copier
- `H` toggle fichiers cachés, `I` toggle gitignorés, `P` toggle preview, `q` fermer

Le picker affiche les fichiers cachés et respecte `.gitignore` nativement.

### 📑 Gestion des Buffers

| Raccourci            | Description                |
| -------------------- | -------------------------- |
| `Tab`                | Buffer suivant             |
| `Shift-Tab`          | Buffer précédent           |
| `F12` ou `<leader>b` | Liste des buffers (picker) |

Les buffers ouverts sont affichés en onglets (bufferline).

### 🚀 Navigation rapide (leap)

| Raccourci       | Description                       |
| --------------- | --------------------------------- |
| `s{char}{char}` | Sauter vers 2 caractères (labels) |
| `S{char}{char}` | Sauter vers une autre fenêtre     |

### ⌨️ Autocomplétion (blink.cmp)

Popup automatique avec suggestions LSP (avec documentation), snippets, mots du buffer, chemins.

| Raccourci           | Description                                                   |
| ------------------- | ------------------------------------------------------------- |
| `Tab` / `Shift-Tab` | Élément suivant/précédent (ou saut de placeholder de snippet) |
| `Enter`             | Confirmer (sélectionne le 1er élément si aucun choix)         |
| `Ctrl-y`            | Confirmer (alternative)                                       |
| `Ctrl-e`            | Fermer le popup                                               |
| `Ctrl-Space`        | Forcer l'affichage                                            |
| `Ctrl-f` / `Ctrl-b` | Scroller la documentation                                     |

Les parenthèses sont ajoutées automatiquement à l'acceptation d'une fonction (auto_brackets).

### 🔧 LSP - Navigation et Actions

**Actifs quand un serveur LSP est attaché** (Lua, Python, Bash, JS/TS, Svelte, Rust, Java)

| Raccourci                 | Description                  |
| ------------------------- | ---------------------------- |
| `gd`                      | Go to Definition             |
| `gD`                      | Go to Declaration            |
| `grr`                     | Find References              |
| `gri`                     | Go to Implementation         |
| `gO`                      | Document symbols (outline)   |
| `H`                       | Hover (documentation)        |
| `<leader>n` / `<leader>N` | Diagnostic suivant/précédent |
| `<leader>e`               | Erreur détaillée en float    |
| `grn` ou `<leader>rn`     | Rename                       |
| `gra` ou `<leader>ca`     | Code Action                  |

Les diagnostics s'affichent en **inline discret** sur la ligne du curseur
(tiny-inline-diagnostic, preset ghost) — pas de virtual text permanent.

### 💬 Commentaires (natif Neovim)

| Raccourci           | Mode          | Description                        |
| ------------------- | ------------- | ---------------------------------- |
| `gcc`               | Normal        | Toggle commentaire ligne courante  |
| `gc`                | Visuel        | Toggle commentaire de la sélection |
| `<leader>c<leader>` | Normal/Visuel | Alias historique                   |

### 🌿 Git

| Raccourci    | Description                           |
| ------------ | ------------------------------------- |
| `<leader>lg` | LazyGit (interface complète en float) |

**Fugitive** (mode commande) : `:Git status`, `:Git blame`, `:Gdiffsplit`, `:Git push`…

**Gitsigns** : modifications affichées dans la marge (`+`, `~`, `_`).

### ✏️ Édition et Formatage

| Raccourci   | Mode      | Description                                    |
| ----------- | --------- | ---------------------------------------------- |
| `<leader>f` | Normal    | Formater le buffer (conform.nvim)              |
| `Shift-Tab` | Insertion | Déindenter la ligne                            |
| `J` / `K`   | Normal    | Scroll rapide bas (2 lignes) / haut (3 lignes) |

> **Note :** `K` est utilisé pour le scroll. Pour la documentation LSP, utiliser `H`.

### 🔄 Configuration

| Raccourci         | Description                       |
| ----------------- | --------------------------------- |
| `<leader><Enter>` | Recharger la configuration Neovim |

### 🔑 Which-key

Tapez `<leader>` et attendez 500ms → popup des raccourcis disponibles :

- `<leader>f...` - Find/Format
- `<leader>c...` - Comment
- `<leader>l...` - LazyGit

## Résumé des touches de fonction

| Touche | Action            |
| ------ | ----------------- |
| `F9`   | Toggle explorer   |
| `F12`  | Liste des buffers |

## Plugins installés

### Core

- **lazy.nvim** - Gestionnaire de plugins
- **gruvbox.nvim** (ellisonleao) - Colorscheme (port Lua, groupes treesitter/floats)

### Navigation et Fichiers

- **snacks.nvim** - Picker (fuzzy finder), explorer, indent guides, lazygit
- **leap.nvim** - Navigation rapide par 2 caractères
- **bufferline** - Onglets de buffers

### UI

- **lualine** - Barre de statut
- **which-key** - Affiche les raccourcis disponibles
- **tiny-inline-diagnostic** - Diagnostics inline discrets
- **nvim-colorizer** (fork NvChad) - Couleurs CSS

### Git

- **gitsigns** - Indicateurs Git dans la marge
- **vim-fugitive** - Intégration Git complète

### Édition

- **nvim-autopairs** - Fermeture automatique des paires
- **conform.nvim** - Formatage (stylua, ruff, prettier, xmllint)

### LSP et Complétion

- **blink.cmp** - Moteur de complétion (snippets intégrés via friendly-snippets)
- **nvim-lspconfig** - Configurations des serveurs LSP
- **nvim-jdtls** - LSP Java

### Syntaxe

- **nvim-treesitter** (branche `main`) - Coloration syntaxique

## Désactivation temporaire

### LSP spécifiques

Pour désactiver un LSP, retirez-le de la liste dans `init.lua` :

```lua
vim.lsp.enable({ "pyright", "bashls", "ts_ls", "svelte", "rust_analyzer", "ruff", "lua_ls" })
```

## Résolution de problèmes

### Les icônes ne s'affichent pas

→ Vérifiez que Hack Nerd Font est installée et sélectionnée dans votre terminal

### Pas de coloration syntaxique

→ Les parsers Treesitter (branche `main`) se compilent au premier lancement :
vérifiez `tree-sitter --version` et qu'un compilateur C est présent

### La complétion ne propose que des mots du buffer

→ Aucun serveur LSP attaché : vérifiez `:lua print(vim.inspect(vim.lsp.get_clients()))`
et l'installation du serveur (section "Serveurs LSP")

### LazyGit ne s'ouvre pas

→ Installez le binaire : `brew install lazygit` / voir https://github.com/jesseduffield/lazygit

### Fichiers non rechargés automatiquement

→ `autoread` est activé dans la config ; les fichiers sont rechargés au focus/changement de buffer

## Personnalisation

Tous les réglages sont dans `~/.config/nvim/init.lua`, organisé en sections :

1. Settings de base
2. Autocmds (indentation par filetype)
3. Mappings
4. Bootstrap lazy.nvim
5. Plugins (avec configurations détaillées)
6. Configuration LSP
7. Java (jdtls)

N'hésitez pas à adapter selon vos besoins !
