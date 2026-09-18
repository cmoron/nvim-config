#!/usr/bin/env bash
# ============================================================================
# Script d'export de la configuration Neovim pour installation offline
#
# Stratégie : copier les plugins verrouillés et installés localement
# (~/.local/share/nvim/lazy/) plutôt que de re-cloner une liste en dur.
# Avantages :
#   - lazy-lock.json est la seule liste de plugins à maintenir
#   - le binaire fuzzy précompilé de blink.cmp est inclus
#   - les branches pinées (nvim-treesitter main) sont respectées
# Les parsers treesitter (branche main) sont copiés depuis
# ~/.local/share/nvim/site/parser/ (binaires arm64 macOS : la cible doit
# avoir la même architecture/OS).
# ============================================================================

set -euo pipefail

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

# Valider avant d'effacer un export précédent. Python ne sert qu'à lire le JSON.
PLUGIN_LOCK=$(python3 - "$REPO_DIR/lazy-lock.json" <<'PY'
import json, re, sys
for name, entry in json.load(open(sys.argv[1])).items():
    if not re.fullmatch(r"[A-Za-z0-9_-][A-Za-z0-9_.-]*", name) or not re.fullmatch(r"[0-9a-f]{40}", entry["commit"]):
        sys.exit("Entrée de lockfile invalide : " + name)
    print(name, entry["commit"])
PY
)
while read -r plugin revision; do
    if [ ! -d "$LAZY_DIR/$plugin/.git" ] \
        || [ "$(git -C "$LAZY_DIR/$plugin" rev-parse HEAD)" != "$revision" ] \
        || [ -n "$(git -C "$LAZY_DIR/$plugin" status --porcelain --untracked-files=no)" ]; then
        echo "Erreur: $plugin absent, modifié ou différent du lockfile ; exécutez :Lazy restore avant l'export." >&2
        exit 1
    fi
done <<< "$PLUGIN_LOCK"

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
while read -r plugin revision; do
    cp -R "$LAZY_DIR/$plugin" "$PLUGINS_DIR/"
done <<< "$PLUGIN_LOCK"
PLUGIN_COUNT=$(find "$PLUGINS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
echo -e "${GREEN}✓${NC} $PLUGIN_COUNT plugins copiés"

# Nettoyer les dossiers .git pour économiser de l'espace
find "$PLUGINS_DIR" -name ".git" -type d -prune -exec rm -rf {} +

# Dossiers de CI des plugins : jamais lus par Neovim, et nvim-jdtls y cache un
# lien symbolique relatif (.github/linters/.luacheckrc) qui fait échouer le
# détar sur un système de fichiers sans symlinks — clé USB exFAT, partage CIFS.
find "$PLUGINS_DIR" -maxdepth 2 -name ".github" -type d -prune -exec rm -rf {} +

# Fixtures de développement (notamment les médias Snacks), inutiles au runtime.
find "$PLUGINS_DIR" -mindepth 2 -maxdepth 2 -type d \
    \( -name tests -o -name test \) -prune -exec rm -rf {} +

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
if compgen -G "$PARSER_DIR/*.so" >/dev/null; then
    mkdir -p "$TREESITTER_PARSER_DEST"
    cp "$PARSER_DIR"/*.so "$TREESITTER_PARSER_DEST/"
    PARSER_COUNT=$(find "$TREESITTER_PARSER_DEST" -name '*.so' -type f | wc -l | tr -d ' ')
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
cp "$SCRIPT_DIR/install-offline.sh" "$EXPORT_DIR/install.sh"

chmod +x "$EXPORT_DIR/install.sh"

# Créer la documentation des dépendances
cat > "$EXPORT_DIR/DEPENDENCIES.md" << 'DEPS_DOC'
# Dépendances du bundle offline

Ce bundle copie l'état de la machine d'export. Il n'embarque pas tous les
outils de développement. Vérifie son contenu avant de le transférer.

| Fonction | Contenu embarqué / prérequis cible |
| --- | --- |
| Éditeur | Neovim >= 0.12 requis ; runtime fourni seulement si `nvim-linux-*.tar.gz` est présent |
| Plugins | Uniquement les plugins du lockfile ; commits et absence de modifications suivies vérifiés avant export |
| Coloration | Parsers natifs dans `treesitter-parsers/`, queries dans le plugin Treesitter |
| Complétion | blink.cmp et son binaire si présent ; sans LSP, pas de complétion sémantique |
| Recherche | `rg` requis pour le grep ; `fd` recommandé |
| Git | `git` requis pour Fugitive/gitsigns ; `lazygit` pour `<leader>lg` |
| Java | jdtls/debug/tests copiés seulement s'ils étaient installés ; JDK compatible non inclus |
| Autres LSP / formatters | Non inclus : à provisionner séparément |

La JVM requise dépend de la version de jdtls exportée : JDK 25 pour la
release 1.61 qualifiée ici ; vérifier les exigences des versions historiques. `JDTLS_JAVA_HOME`
permet de la séparer du Java du projet. Les projets Maven/Gradle ont aussi
besoin de leurs dépendances et outils de build disponibles hors ligne.

## Préparer les outils sur une machine connectée

Les commandes suivantes nécessitent un réseau ou un miroir préalablement
configuré. Elles ne constituent pas une installation offline :

```bash
bun install -g pyright bash-language-server typescript typescript-language-server svelte-language-server prettier
uv tool install ruff
cargo install stylua
rustup component add rust-analyzer
go install golang.org/x/tools/gopls@latest
go install golang.org/x/tools/cmd/goimports@latest
```

Les lanceurs JS peuvent nécessiter `node` dans le PATH, même installés avec
Bun. Installer aussi `lua-language-server`, `xmllint`, `git`, `rg`, `fd` selon
les paquets disponibles sur la cible. Aucun de ces outils n'est ajouté par
l'installeur offline.

## Compatibilité native

`PLATFORM` vérifie uniquement OS et architecture, **pas la glibc, libstdc++ ou
les autres bibliothèques partagées**. Un export depuis une distribution Linux
récente n'est pas une preuve de compatibilité Oracle Linux 8 / RHEL 9.
Aucune compilation n'est nécessaire sur la cible si tous les parsers et le
binaire blink sont présents et compatibles. Sinon, reconstruire le bundle
sur une base compatible ; un téléchargement ne fonctionnera pas hors ligne.

## Vérification sur la cible

```bash
nvim --version
command -v git rg fd lazygit
java -version
```

Dans Neovim : `:checkhealth`, `:ConformInfo`, puis ouvrir un fichier de chacun
des langages réellement utilisés. Vérifier les diagnostics et la complétion
avec le serveur correspondant, pas uniquement le démarrage de l'éditeur.

DEPS_DOC

# Créer le README
cat > "$EXPORT_DIR/README.md" << 'README'
# Configuration Neovim — bundle offline

Snapshot des plugins verrouillés de la machine d'export, avec les parsers natifs et les
composants Java disponibles. Ce n'est pas une distribution de développement
entièrement autonome : voir [DEPENDENCIES.md](DEPENDENCIES.md).

## Installation

```bash
tar -xzf nvim-config-offline.tar.gz
./nvim-config-offline/install.sh
```

Le script fonctionne depuis n'importe quel dossier, refuse un OS/CPU différent
et exige un Neovim >= 0.12 exécutable. Si un `nvim-linux-*.tar.gz` accompagne
le bundle, il installe ce runtime quand le Neovim existant ne convient pas.
Le contrôle OS/CPU ne garantit pas la compatibilité des bibliothèques système.

Tout est installé sous `$HOME`, sans droits root :

- `~/.config/nvim` : configuration ;
- `~/.local/share/nvim` : plugins, parsers et queries ;
- `~/.local/share/neovim` et `~/.local/bin/nvim` : runtime, si fourni ;
- `~/.local/share/{jdtls,java-debug,java-test}` : composants Java, si fournis.

La configuration, les données Neovim et les composants Java remplacés sont
renommés avec un suffixe `.bak-<date>-<pid>`. Un symlink est sauvegardé sans
modifier sa cible. Conserve ces sauvegardes jusqu'à validation ; elles ne sont
pas purgées automatiquement. Le runtime Neovim embarqué est remplacé séparément.
Les chemins XDG personnalisés ne sont pas pris en charge par ces scripts.

Pour exposer le runtime aux prochains shells, ajoute si nécessaire :

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Vérification et dépannage

- `nvim --version`, puis `:checkhealth` et `:ConformInfo`.
- Absence de coloration : vérifier `~/.local/share/nvim/site/parser/` et
  `~/.local/share/nvim/site/queries/` ; reconstruire si incomplets.
- Erreur de bibliothèque native : reconstruire pour l'OS/CPU et la base système
  cibles. Ne pas supprimer `PLATFORM` pour contourner une incompatibilité.
- Pas de LSP : installer le serveur externe ; les plugins ne le fournissent pas.
- Java : vérifier le JDK requis par jdtls, `JDTLS_JAVA_HOME` et les jars présents.
- `<leader>g` : nécessite ripgrep ; `<leader>lg` : nécessite lazygit.

Leader : Espace. `F9` ouvre l'explorer, `Ctrl-P` cherche des fichiers,
`F12` liste les buffers, `<leader>f` formate, `H` affiche l'aide LSP,
`gcc` commente et `s` lance Leap.

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
    PARSER_COUNT=$(find "$TREESITTER_PARSER_DEST" -name '*.so' -type f | wc -l | tr -d ' ')
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
