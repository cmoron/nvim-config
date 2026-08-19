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

| Langage              | Serveur LSP                | Installé via                                                                       |
| -------------------- | -------------------------- | ---------------------------------------------------------------------------------- |
| Lua                  | lua-language-server        | `brew install lua-language-server`                                                 |
| Python               | Pyright                    | `npm install -g pyright`                                                           |
| Python (lint/format) | Ruff                       | `uv tool install ruff`                                                             |
| Bash                 | bash-language-server       | `npm install -g bash-language-server`                                              |
| JS/TS                | typescript-language-server | `npm install -g typescript-language-server typescript`                             |
| Svelte               | svelte-language-server     | `npm install -g svelte-language-server`                                            |
| Rust                 | rust-analyzer              | `rustup component add rust-analyzer`                                               |
| Go                   | gopls                      | `go install golang.org/x/tools/gopls@latest`                                       |
| Java                 | jdtls                      | `scripts/install.sh` (si JDK 21+ présent) ; le bundle offline l'embarque aussi     |
| Java (debug)         | java-debug-adapter         | `scripts/install.sh`, extrait de l'extension VS Code → `~/.local/share/java-debug` |
| Java (tests)         | vscode-java-test           | `scripts/install.sh`, extrait de l'extension VS Code → `~/.local/share/java-test`  |

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
blink.cmp + parsers Treesitter pré-compilés + chaîne Java jdtls/debug/tests)
transférable sur une machine sans connexion :

```bash
scripts/export-offline.sh
# → dist/nvim-config-offline.tar.gz
```

⚠️ Les binaires sont compilés pour l'architecture de la machine d'export. Le
bundle enregistre sa plateforme dans `PLATFORM` et son `install.sh` refuse une
cible différente.

**Cible d'une autre plateforme** — `scripts/export-offline-linux.sh` rejoue
l'export dans un conteneur Docker de la bonne architecture, et embarque en plus
le runtime Neovim 0.12+ (extrait sous `~/.local`, donc installable sans droits
root et sur un système à racine immuable) :

```bash
scripts/export-offline-linux.sh              # cible Linux x86_64
ARCH=arm64 scripts/export-offline-linux.sh   # cible Linux aarch64
# → dist/nvim-config-offline-linux-<arch>.tar.gz
```

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

- **lazy.nvim** — Gestionnaire de plugins : bootstrap automatique au premier
  lancement, versions figées par `lazy-lock.json`, chargement paresseux
  (`event`, `ft`, `keys`) pour un démarrage rapide.
- **gruvbox.nvim** (ellisonleao) — Colorscheme. Port Lua qui définit
  `NormalFloat` et les groupes treesitter, contrairement au gruvbox historique
  qui laissait un fond noir sur les fenêtres flottantes.

### Navigation et Fichiers

- **snacks.nvim** — Couteau suisse qui remplace à lui seul Telescope, NvimTree
  et BufExplorer. Modules activés : **picker** (fichiers `Ctrl-P`, grep
  `<leader>g`, buffers, aide, diagnostics, références et symboles LSP),
  **explorer** (`F9`, révélation du fichier courant `<leader><Tab>`),
  **indent** (guides d'indentation) et **lazygit** (`<leader>lg`).
- **leap.nvim** — Saut vers n'importe quel point visible en tapant 2 caractères
  puis un label (`s` dans la fenêtre courante, `S` vers une autre fenêtre).
  Installé depuis son miroir Codeberg.
- **bufferline.nvim** — Onglets de buffers en haut de l'écran (`Tab` /
  `Shift-Tab` pour naviguer), avec un décalage réservé à l'explorer.

### UI

- **lualine** — Barre de statut (thème gruvbox) : mode, branche Git,
  diagnostics, position.
- **which-key** — Popup des raccourcis disponibles après `<leader>` (500 ms),
  avec les groupes Find/Format, Comment et LazyGit.
- **tiny-inline-diagnostic** — Diagnostics affichés en fin de ligne du curseur
  uniquement (preset « ghost », multi-lignes) : pas de virtual text permanent
  qui pollue tout l'écran.
- **nvim-colorizer** (fork NvChad) — Prévisualisation des couleurs dans le
  buffer (`#RRGGBB`, `rgb()`, `hsl()`, noms CSS), tous filetypes.
- **nvim-web-devicons** — Icônes de filetypes (dépendance de bufferline et
  lualine, nécessite une Nerd Font).

### Git

- **gitsigns** — Hunks dans la gouttière (`+`, `~`, `_`) sur l'état du working
  tree.
- **vim-fugitive** — Git en mode commande : `:Git status`, `:Git blame`,
  `:Gdiffsplit`, `:Git push`…
- **lazygit** (via snacks.nvim) — Interface Git complète en fenêtre flottante
  (`<leader>lg`). Nécessite le binaire `lazygit` sur la machine.

### Édition

- **nvim-autopairs** — Fermeture automatique des parenthèses, quotes et
  crochets ; l'insertion des parenthèses à l'acceptation d'une complétion est
  gérée par blink.cmp (`auto_brackets`).
- **conform.nvim** — Formatage à la demande (`<leader>f`, jamais à la
  sauvegarde) : stylua, ruff, prettier, xmllint, goimports selon le filetype,
  trim des espaces partout, et délégation au serveur LSP pour les langages
  sans formatter dédié.

### LSP, Complétion et Debug

- **blink.cmp** — Moteur de complétion (LSP, chemins, snippets, mots du
  buffer) avec documentation intégrée. Le matching flou repose sur un binaire
  Rust précompilé — pas de dépendance à cargo, et le bundle offline
  l'embarque.
- **friendly-snippets** — Collection de snippets communautaires consommée par
  blink.cmp.
- **nvim-lspconfig** — Définitions des serveurs LSP, activés via l'API native
  `vim.lsp.enable()` (voir la section « Serveurs LSP »).
- **nvim-jdtls** — Intégration Java : chargé uniquement sur `ft=java`, gère le
  workspace jdtls, la détection de racine de projet (Maven, Gradle, Ant), la
  JVM du serveur (`JDTLS_JAVA_HOME`) séparée de celle du projet, et branche
  java-debug / vscode-java-test sur nvim-dap.
- **nvim-dap** + **nvim-dap-ui** (+ **nvim-nio**) — Débogueur : breakpoints
  (`<leader>db`, conditionnel `<leader>dB`), exécution `F5` / `F10` / `F11`,
  panneaux ouverts automatiquement au premier arrêt réel — un test qui passe
  ne fait pas clignoter l'écran.

### Syntaxe

- **nvim-treesitter** (branche `main`) — Coloration et analyse syntaxiques.
  La liste des parsers (22 langages) est exposée dans `vim.g.ts_parsers`,
  compilée au premier lancement (CLI `tree-sitter` + compilateur C) et
  précompilée dans le bundle offline.

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
