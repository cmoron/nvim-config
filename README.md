# Configuration Neovim

Configuration Neovim personnelle, moderne et minimaliste (Neovim 0.12+).

Stack actuelle : **snacks.nvim** (picker, explorer, indent, lazygit), **blink.cmp** (complétion),
**nvim-treesitter** (branche `main`), **leap**, **tiny-inline-diagnostic**, **gruvbox**.

> **Versions :** la migration de stack commence à `v2.0.0` ; les tags `v3.0.0`
> et `v3.1.0` sont également présents. `v1.0.0` conserve l’ancienne stack
> (Telescope, nvim-cmp, nvim-tree, harpoon…). `lazy-lock.json` fixe les plugins.

## Prérequis

### Version Neovim

- **Neovim >= 0.12** : exigé par le commit verrouillé de nvim-treesitter `main`
  (l’API `vim.lsp.config` existe dès 0.11). Vérifier la version réellement installée.

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
sudo apt install -y git curl ripgrep fd-find build-essential python3 unzip
```

- **git** : gestion des plugins et vim-fugitive
- **ripgrep** / **fd** : recherche du picker Snacks (grep / find files)
- **lazygit** : interface Git dans Neovim (`<leader>lg`) — optionnel
- **tree-sitter-cli >= 0.26.1** : compilation des parsers Treesitter (`main`).
  Sous Linux : `cargo install --locked tree-sitter-cli`, ou binaire des
  [releases officielles](https://github.com/tree-sitter/tree-sitter/releases).
  Le plugin déconseille l’installation du CLI via un gestionnaire JS.
- **build-essential** : compilateur C pour les parsers (Linux uniquement)

#### 2. Python (via uv)

Ne pas utiliser `pip` système. Installer **uv** :

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install ruff
```

#### 3. Outils JavaScript

Installer un runtime Node compatible avec les serveurs choisis (Node 24 LTS
est une base actuelle) et **Bun** pour installer les outils :

```bash
bun install -g pyright prettier bash-language-server typescript typescript-language-server svelte-language-server
```

Bun est le gestionnaire employé par `install.sh`. Les lanceurs de certains
outils utilisent `#!/usr/bin/env node` : installer avec Bun ne dispense donc
pas automatiquement de Node. Node 20 est arrivé en fin de vie ; consulter le
[calendrier Node.js](https://nodejs.org/en/about/previous-releases).

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
| JS/TS/HTML/CSS/JSON/YAML/MD | Prettier  | `bun install -g prettier`                            |
| Lua                         | StyLua    | `cargo install stylua` / `brew install stylua`       |
| XML                         | xmllint   | `apt install libxml2-utils` / `brew install libxml2` |

> **Note :** le LSP est préféré seulement pour les filetypes sans formatter
> dédié. Si un formatter configuré est absent, il n’y a pas de repli LSP.
> Go utilise `goimports` puis `gofmt` ; installer `goimports` avec
> `go install golang.org/x/tools/cmd/goimports@latest`.

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
| Python               | Pyright                    | `bun install -g pyright`                                                           |
| Python (lint/format) | Ruff                       | `uv tool install ruff`                                                             |
| Bash                 | bash-language-server       | `bun install -g bash-language-server`                                              |
| JS/TS                | typescript-language-server | `bun install -g typescript-language-server typescript`                             |
| Svelte               | svelte-language-server     | `bun install -g svelte-language-server`                                            |
| Rust                 | rust-analyzer              | `rustup component add rust-analyzer`                                               |
| Go                   | gopls                      | `go install golang.org/x/tools/gopls@latest`                                       |
| Java                 | jdtls                      | `scripts/install.sh` (si JDK 25+ présent) ; le bundle offline l'embarque aussi     |
| Java (debug)         | java-debug-adapter         | `scripts/install.sh`, extrait de l'extension VS Code → `~/.local/share/java-debug` |
| Java (tests)         | vscode-java-test           | `scripts/install.sh`, extrait de l'extension VS Code → `~/.local/share/java-test`  |

Les outils `lua-language-server`, `goimports` et les runtimes de langages
sont à installer séparément. L’installation de `rust-analyzer` est suggérée
mais pas exécutée par le script. Pour Java, `JDTLS_JAVA_HOME` sélectionne
la JVM de jdtls, distincte du Java du projet ; `JAVA8_HOME`, `JAVA11_HOME`,
`JAVA17_HOME`, `JAVA21_HOME`, `JAVA25_HOME` (et toutes les versions de 8 à 25)
déclarent les runtimes de projets disponibles. Le bundle EL8 embarque le JDK 25
du serveur ; le JDK du projet, notamment Java 8, reste distinct.

### Vérification

```bash
command -v lua-language-server pyright bash-language-server typescript-language-server svelteserver rust-analyzer
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

Un dossier de configuration existant est sauvegardé en
`~/.config/nvim.bak-<horodatage>`. En online, un autre symlink est remplacé
sans modifier son dossier cible.

| Option            | Effet                                        |
| ----------------- | -------------------------------------------- |
| `-c`, `--check`   | Vérifie prérequis et outils, n'installe rien |
| `-n`, `--dry-run` | Affiche les actions sans les exécuter        |

### Installation offline

Le script `scripts/export-offline.sh` exporte les **22 plugins verrouillés**,
les parsers natifs disponibles et les composants Java installés. Il requiert
Python 3 et Git pour vérifier le lockfile, et refuse les plugins absents,
modifiés ou à un autre commit. Les anciens plugins hors lockfile sont exclus.
Les fichiers non suivis (dont les binaires blink) restent copiés.

```bash
# Si nécessaire, restaurer les versions voulues dans Neovim : :Lazy restore
# Puis mettre à jour les parsers pour ce commit : :TSUpdate
scripts/export-offline.sh
# → dist/nvim-config-offline.tar.gz
```

L’export local ne fournit Neovim que si `NVIM_TARBALL` pointe vers une archive
`nvim-linux-*.tar.gz`. Il ne fournit **ni JDK, ni runtime Node, ni LSP externes,
ni formatters, ni rg/fd/git/lazygit**. Un dossier de parsers vide est signalé ;
le bundle reste incomplet pour la coloration hors ligne. Java est inclus
seulement si les composants étaient installés sur la machine d’export.

`PLATFORM` vérifie l’OS et le CPU, **pas la compatibilité glibc/libstdc++**.
Les parsers exportés doivent correspondre au plugin Treesitter verrouillé.

Le wrapper Linux construit dans Docker (`fedora:43` par défaut), embarque
Neovim `v0.12.5` et utilise le CLI Tree-sitter `v0.26.1` officiel :

```bash
scripts/export-offline-linux.sh
ARCH=arm64 scripts/export-offline-linux.sh
# → dist/nvim-config-offline-linux-{x86_64,arm64}.tar.gz
# Réglages : NVIM_VERSION, TREE_SITTER_VERSION, BUN_VERSION, IMAGE (base dnf compatible)
```

Le build exige un Docker fonctionnel et du réseau. Les versions des plugins
et jdtls 1.61.0 sont verrouillés, mais l’image Fedora de base et les extensions
VS Code restent mobiles : le build n’est pas encore entièrement reproductible.
**L’archive du 18 septembre 2026 est validée sur Fedora 43 et UBI 9.6
(base RHEL 9), sans root ni réseau. Elle est incompatible avec Oracle Linux 8.**
La recette dédiée ci-dessous remplace le runtime pour OL8 et ajoute les outils
Java/Python. Chaque nouvelle archive doit repasser la recette sur ses cibles.

```bash
scripts/export-offline-el8.sh
# → dist/nvim-config-offline-el8-x86_64.tar.gz et .sha256
```

Ce bundle EL8 fournit Neovim 0.12.5 compilé sur OL8, jdtls 1.61.0,
un JDK 25 privé, Node 24, Pyright et Ruff. Il réutilise les plugins et parsers
du bundle Linux. Les JDK des projets Java 8 à 24, les environnements Python
et les dépendances Maven/Gradle restent à fournir. Voir le
[guide OL8 Java/Python](docs/offline-el8.md) pour les commandes et la matrice
de validation.
Voir l’[étude de packaging Enterprise Linux](docs/packaging-enterprise-linux.md) et
l’[évaluation de compilation OL8 et des versions Neovim](docs/neovim-ol8-build-evaluation.md).

Sur la cible :

```bash
tar -xzf nvim-config-offline.tar.gz
./nvim-config-offline/install.sh
```

L’installation ne demande pas de droits root. La configuration, les données
Neovim et les composants Java remplacés sont déplacés vers des sauvegardes
`.bak-<date>-<pid>` ; un symlink n’est pas suivi. Ces sauvegardes sont conservées
jusqu’à suppression manuelle. Le runtime embarqué et le lanceur `~/.local/bin/nvim` sont également
sauvegardés avant remplacement. Ajouter `~/.local/bin` au PATH.
Les scripts utilisent les chemins HOME standards, sans prise en charge XDG
personnalisée. Consulter aussi les README et DEPENDENCIES générés dans le bundle.

Les [GitHub Releases](https://github.com/cmoron/nvim-config/releases) hébergent
le bundle EL8 qualifié et son SHA-256. Les binaires ne sont pas committés ;
les caches de build vivent sous `~/.cache/nvim-config/`.

### Contrôles du dépôt

```bash
bash scripts/test-packaging.sh    # fixtures isolées, aucun téléchargement
shellcheck scripts/*.sh
stylua --check init.lua scripts/check-runtime.lua scripts/check-lsp.lua
scripts/install.sh --check
# Après construction du bundle ; Docker doit disposer de l'image cible :
bash scripts/test-offline-linux.sh
bash scripts/test-offline-linux.sh dist/nvim-config-offline-linux-x86_64.tar.gz registry.access.redhat.com/ubi9/ubi:9.6
```

Les tests de packaging vérifient les installations et sauvegardes avec de faux
binaires ; ils ne prouvent pas l’ABI d’une cible Linux. Le test Docker installe
l’archive sous un utilisateur non privilégié, sans réseau, puis charge les
23 parsers, leurs queries et le moteur Rust de blink. Le wrapper exécute aussi
ce contrôle de runtime avant de publier l’archive. Voir le
[rapport de revue](docs/review-2026-09-18.md) pour les validations réelles et
les limites restantes.

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

| Raccourci            | Description                              |
| -------------------- | ---------------------------------------- |
| `Tab`                | Buffer suivant                           |
| `Shift-Tab`          | Buffer précédent                         |
| `F12` ou `<leader>b` | Liste des buffers (picker)               |
| `<leader>x`          | Fermer le buffer en gardant les fenêtres |

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

**Actifs quand un serveur LSP est attaché** (Lua, Python, Bash, JS/TS, Svelte, Rust, Go, Java)

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

| Raccourci   | Mode      | Description                                      |
| ----------- | --------- | ------------------------------------------------ |
| `<leader>f` | Normal    | Formater le buffer (conform.nvim)                |
| `Shift-Tab` | Insertion | Complétion/snippet si actif, sinon déindentation |
| `J` / `K`   | Normal    | Scroll rapide bas (2 lignes) / haut (3 lignes)   |

> **Note :** `K` est utilisé pour le scroll. Pour la documentation LSP, utiliser `H`.

### 🔄 Configuration

| Raccourci         | Description                                                    |
| ----------------- | -------------------------------------------------------------- |
| `<leader><Enter>` | Ancien raccourci `:source` (rechargement partiel, déconseillé) |

Redémarrer Neovim après modification : lazy.nvim ne prend pas en charge le
rechargement complet et les autocmds se dupliquent avec ce raccourci.

### 🔑 Which-key

Tapez `<leader>` et attendez le délai du plugin (preset `modern`) → popup des raccourcis disponibles :

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
- **which-key** — Popup des raccourcis disponibles après `<leader>` (délai du plugin),
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
  La liste des parsers (23 entrées) est exposée dans `vim.g.ts_parsers`,
  compilée au premier lancement avec interface (CLI `tree-sitter` + compilateur
  C) et précompilée dans le bundle offline. Sans interface attachée, le script
  de build déclenche et attend explicitement l’installation ; un serveur
  Neovim démarré sans UI demande également une installation explicite.

## Désactivation temporaire

### LSP spécifiques

Pour désactiver un LSP, retirez-le de la liste dans `init.lua` :

```lua
vim.lsp.enable({ "pyright", "bashls", "ts_ls", "svelte", "rust_analyzer", "ruff", "lua_ls", "gopls" })
```

### Java et débogage

Le [pense-bête Java](docs/java-cheatsheet.html) détaille le parcours.
`<leader>tc` lance les tests de la classe, `<leader>tm` la méthode courante
(si le lanceur Java est présent). `F5` lance/continue, `F10` avance sans entrer,
`F11` entre, `<leader>do` sort, `<leader>dt` arrête, `<leader>du` ouvre les panneaux.
`<leader>db` pose un breakpoint et `<leader>dB` un breakpoint conditionnel.
Le serveur et les dépendances Maven/Gradle doivent être provisionnés avant
utilisation hors ligne.

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
