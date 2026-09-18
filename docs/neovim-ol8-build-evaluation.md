# Évaluation de compilation Neovim sur Oracle Linux 8

Étude initiale : 18 septembre 2026. Périmètre : x86_64.

**Suite réalisée le 19 septembre :** Neovim 0.12.5 a compilé avec GCC 8.5.0
et CMake 3.26.5 sur OL8. Le runtime demande au maximum glibc 2.28. La recette
et les résultats Java/Python sont décrits dans le [guide du bundle](offline-el8.md).
Les paragraphes ci-dessous conservent l'évaluation antérieure au build.

Au moment de l'étude initiale, le client Docker utilisé depuis WSL ne
donnait pas accès au moteur : aucun build OL8 n'avait été lancé. Les versions ci-dessous sont des observations des
index Oracle à cette date ; le futur build devra résoudre puis consigner les
NEVRA exacts et les checksums.

## Conclusion

Oui, le build dynamique de Neovim `v0.12.5` dans OL8 est raisonnable, sans
mettre à niveau la glibc de la cible ni embarquer un compilateur. Le compilateur
standard d'OL8 satisfait les prérequis annoncés : la source impose CMake >= 3.16, documente GCC >= 4.9,
utilise GNU99 dans le core et C11 pour libuv. OL8 propose GCC 8.5.0 et CMake
3.26.5. Construire dans OL8 fixe l'ABI glibc maximale au socle 2.28, sous
réserve du contrôle ELF final.

La première réalisation peut donc rester minimale : compiler Neovim et ses
dépendances _bundled_ dans un conteneur OL8, puis remplacer son runtime dans
une copie du bundle existant. Les parsers et blink actuels sont candidats à
la réutilisation après réception réelle sur OL8 ; leur inspection ELF ne
montre pas le blocage glibc du binaire Neovim officiel. La réussite avec GCC 8
reste à confirmer par compilation. Ne pas installer une glibc récente, ni la
copier dans le bundle.

## Une version plus ancienne aiderait-elle ?

Non pour notre configuration actuelle. Le lock épingle `nvim-treesitter`
`main` au commit `8b98b4470eb326f1c7b50dae79f8c963568e5720`, qui exige
[Neovim >= 0.12](https://github.com/nvim-treesitter/nvim-treesitter/blob/8b98b4470eb326f1c7b50dae79f8c963568e5720/README.md).
Le tableau combine cette contrainte avec une inspection `readelf --version-info`
des tarballs officiels Linux x86_64 téléchargés pour l'étude. OL8 fournit
glibc 2.28.

| Neovim | GLIBC maximale requise par le binaire officiel | Impact sur notre configuration                             | Gain pour OL8                                               |
| ------ | ---------------------------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------- |
| 0.12.5 | 2.34                                           | version du bundle actuel                                   | compilation OL8 nécessaire                                  |
| 0.12.0 | 2.34                                           | respecte le minimum déclaré du lock ; exécution non testée | aucun : mêmes prérequis de compilation que 0.12.5           |
| 0.11.7 | 2.34                                           | commit Tree-sitter actuel non supporté                     | aucun : compilation nécessaire et migration de Tree-sitter  |
| 0.10.4 | 2.29                                           | Tree-sitter incompatible et API LSP absentes               | aucun : compilation nécessaire et réécriture supplémentaire |

0.12.0 et 0.12.5 déclarent toutes deux CMake >= 3.16 et GCC >= 4.9 :
rétrograder à 0.12.0 ne simplifie pas la toolchain et retire les correctifs
ultérieurs. Le binaire officiel de 0.11.7 conserve la même exigence glibc.

Une configuration 0.11 serait envisageable en basculant vers l'ancienne
branche `master` gelée de Tree-sitter : remplacer le lock, les parsers et
queries, adapter les appels actuels `setup/install` à l'ancienne API, puis
requalifier les autres plugins. Ce serait une variante distincte à maintenir,
sans bénéfice démontré pour le packaging. Pour 0.10, il faudrait en plus
remplacer `vim.lsp.config` et `vim.lsp.enable`, utilisés dans `init.lua` et
[disponibles dans Neovim 0.11](https://github.com/neovim/neovim/blob/v0.11.7/runtime/doc/lsp.txt),
et choisir un ancien lspconfig compatible. Nous n'avons pas testé tout le
lock sur ces versions : le blocage Tree-sitter suffit à les exclure en l'état.

**Recommandation : conserver 0.12.5 et les commits actuels des plugins.**

## Dépendances de build

Neovim recommande pour RHEL/Fedora : `ninja-build cmake gcc make gettext curl
glibc-gconv-extra git`. `git` et `curl` servent à obtenir les sources ; le
build Neovim avec `USE_BUNDLED=1` télécharge et construit ses dépendances dans
`.deps`. Elles comprennent notamment libuv 1.52.1, LuaJIT, luv 1.52.1-0,
lpeg 1.1, unibilium 2.1.2, utf8proc 2.11.3 et Tree-sitter runtime 0.26.13.
Elles sont liées statiquement hors bibliothèques de base ; cette propriété doit
être vérifiée sur le binaire produit, pas supposée.

Les versions exactes viennent du
[fichier amont `deps.txt`](https://github.com/neovim/neovim/blob/v0.12.5/cmake.deps/deps.txt).
Les URL et SHA-256 sont déjà fournis par Neovim : inutile de créer une recette
de téléchargement et de compilation séparée pour chaque bibliothèque.

| Dépendance privée                 | Version épinglée par Neovim 0.12.5                |
| --------------------------------- | ------------------------------------------------- |
| libuv                             | 1.52.1                                            |
| LuaJIT                            | commit `fbb36bb6bfa88716a47c58bcf9ce9f2ef752abac` |
| luv                               | 1.52.1-0                                          |
| lua-compat-5.3, auxiliaire de luv | 0.13                                              |
| lpeg                              | 1.1.0                                             |
| unibilium                         | 2.1.2                                             |
| utf8proc                          | 2.11.3                                            |
| bibliothèque Tree-sitter          | 0.26.13                                           |

Le build fournit aussi les parsers internes C, Lua, Vim, Vimdoc, Query et
Markdown. Ils ne remplacent pas les 23 parsers configurés par nos plugins.
La **bibliothèque** Tree-sitter 0.26.13 est du C ; elle est distincte du
**CLI** 0.26.1 utilisé pour générer les parsers. Le core Neovim ne demande
donc pas Rust. Wasmtime est désactivé par défaut ; `vterm` et `termkey` sont
déjà intégrés aux sources. Sous Linux, les bibliothèques système iconv/gettext
ne nécessitent pas une chaîne de compilation indépendante.

| Paquet / rôle                                 | Dépôt OL8                 | Version observée                                            | Décision                                                                                       |
| --------------------------------------------- | ------------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `gcc`, `make`, `cmake`                        | AppStream / BaseOS        | GCC 8.5.0-28.0.1, GNU Make 4.2.1-11, CMake 3.26.5-2         | requis                                                                                         |
| `gettext`, `curl`, `git`, `glibc-gconv-extra` | BaseOS / AppStream        | gettext 0.19.8.1-17, curl 7.61.1-34.el8_10.13, Git 2.43.7-1 | requis par la recette amont ou l'acquisition                                                   |
| `ninja-build`                                 | CodeReady Builder         | 1.8.2-1                                                     | optionnel : accélère le build ; GNU Make suffit                                                |
| `pkgconf`, `unzip`                            | BaseOS                    | pkgconf 1.4.2-1, unzip 6.0-48.0.1                           | non requis par le build amont par défaut ; garder seulement si le script de bundle les emploie |
| `clang`                                       | AppStream, flux modulaire | 21.1.8                                                      | inutile : Neovim est un build C avec GCC suffisant                                             |
| `gcc-toolset-15-gcc`                          | AppStream                 | 15.2.1-7.1                                                  | inutile au premier build                                                                       |

Les index Oracle exposent plusieurs générations et flux modulaires. La colonne
« version observée » n'est donc pas une promesse du résolveur DNF ni un pin de
reproductibilité. BaseOS et AppStream suffisent pour la recette minimale si
GNU Make est utilisé. CodeReady Builder est classé par Oracle parmi les dépôts
de développement non pris en charge : ne l'activer que si Ninja est réellement
voulu. Les dépôts `developer` et `developer_EPEL` ne sont pas nécessaires ici.

GCC Toolset et Clang sont des options de confort, pas une solution au problème
OL8. Ils peuvent aussi ajouter des bibliothèques runtime plus récentes. Le
choix prudent est GCC 8 fourni par OL8 ; si un toolset est essayé ensuite, la
recette doit comparer `readelf --version-info` et `ldd` avec le build GCC 8.

## Tree-sitter CLI 0.26.1

Le binaire Linux x64 publié par Tree-sitter `v0.26.1` existe, mais l'inspection
de son ELF donne `GLIBC_2.39` comme exigence maximale. Il ne démarre donc pas
sur OL8 (glibc 2.28) et ne doit pas être copié dans le bundle EL8.

Ce CLI n'est pas requis à l'exécution si les parsers `.so` sont produits avant
l'export. Pour le rendre disponible au build de façon reproductible, le chemin
valide est de compiler le tag `v0.26.1` dans OL8 : son `Cargo.toml` demande
Rust 1.84 et l'édition 2021. Il faut d'abord vérifier qu'un Rust 1.84 ciblant
`x86_64-unknown-linux-gnu` démarre dans le conteneur OL8, puis contrôler l'ELF
résultant. Cette branche n'est pas nécessaire au premier pilote : les parsers
existants ne présentent pas d'exigence GLIBC supérieure à celle d'OL8.

## Ce que l'on peut réutiliser dans l'archive actuelle

Inspection ELF de l'archive Fedora testée précédemment, SHA-256
`0f399372bd83686d20fbae29fd17967dfa13c22ac591231fa781da13805b8bb8` :

| Artefact                       | GLIBC maximale requise | Conclusion limitée à l'inspection ELF     |
| ------------------------------ | ---------------------- | ----------------------------------------- |
| runtime Neovim officiel 0.12.5 | 2.34                   | incompatible OL8, remplacement nécessaire |
| parsers Bash et Markdown       | 2.14                   | pas de blocage glibc identifié            |
| 22 autres parsers, dont `dtd`  | 2.2.5                  | pas de blocage glibc identifié            |
| `libblink_cmp_fuzzy.so`        | 2.17                   | pas de blocage glibc identifié            |

Aucune dépendance GLIBCXX/libstdc++ n'apparaît dans ces parsers ou dans blink.
Ce relevé ne prouve ni leur chargement effectif sur OL8, ni leur compatibilité
CPU : le test runtime reste indispensable. Il permet toutefois de commencer
sans recompiler les parsers, sans Rust et sans reconstruire blink. Une
reconstruction complète des parsers dans OL8 pourra suivre pour homogénéiser
la provenance, ou si la réception révèle une incompatibilité.

## Lots proposés et effort estimé

1. **Prouver le runtime : 2 à 4 heures de travail.** Construire le tag
   0.12.5 avec GCC 8, CMake et GNU Make dans OL8, en mode Release et avec les
   dépendances bundled. Conserver tout l'arbre installé (`bin`, `share`,
   `lib`, dont les parsers internes), pas seulement l'exécutable. Vérifier
   l'ABI et le démarrage dans un conteneur OL8 de réception sans outils de
   compilation, puis sous UBI 9.
2. **Intégrer au bundle et valider : une demi-journée à une journée.**
   Réutiliser une copie de l'archive actuelle, y remplacer le tarball du
   runtime, puis exécuter `scripts/test-offline-linux.sh` sur OL8 et UBI 9.
   Vérifier aussi le déplacement du bundle et l'absence de chemins vers le
   builder. Le script `check-runtime.lua` couvre les 23 parsers configurés,
   leurs queries et le chargement du fuzzy Rust. Ne pas réexporter directement
   les plugins extraits : ils n'ont plus les métadonnées Git exigées par
   l'exporteur. Enfin, intégrer la construction du runtime dans l'export Linux
   et consigner les versions/sommes de contrôle.
3. **Seulement si nécessaire : une demi-journée à une journée supplémentaire.**
   Compiler le CLI Tree-sitter en Rust sous OL8 et régénérer les parsers si
   leur réception échoue ou si l'on veut tout produire dans le même builder.
   Recompiler blink uniquement si son binaire échoue réellement.

Ce sont des estimations d'ingénierie, pas des durées mesurées. Compter environ
**1 à 2 jours pour un premier bundle core qualifié**, avec une marge si les
téléchargements, les dépôts OL8 ou une dépendance contredisent les prérequis
amont. Aucun build n'a été réalisé pendant cette évaluation.

JDK, Node, serveurs LSP et formatters ne sont pas des dépendances de compilation
de Neovim. Les rendre eux aussi autoporteurs reste un lot distinct : le bundle
actuel contient jdtls et ses extensions Java, mais pas leur JDK.

## Contrôles obligatoires après le futur build

1. Construire le tag `v0.12.5` dans `oraclelinux:8`, avec un préfixe dans le
   répertoire d'export et `CMAKE_BUILD_TYPE=Release`.
2. Contrôler `nvim --version`, `ldd` et `readelf --version-info` sur `nvim`,
   chaque parser `.so` et le module blink. Aucun symbole GLIBC requis supérieur à
   2.28 ni dépendance hors bundle/base OL8 ne doit apparaître.
3. Exécuter la recette offline sans réseau sous OL8 puis UBI 9, avec un HOME
   temporaire et sans Neovim hôte.
4. Enregistrer le digest de l'image OL8, les NEVRA DNF, sources Neovim/dépendances,
   checksums et sorties ABI dans le manifeste d'archive.

La compilation croisée ne réduit pas le travail : Neovim l'indique comme non
pleinement prise en charge. Construire directement dans OL8 est plus court et
contrôle naturellement l'ABI cible.

## Sources primaires

- [Neovim v0.12.5 : build et prérequis RHEL/Fedora](https://github.com/neovim/neovim/blob/v0.12.5/BUILD.md)
- [Neovim v0.12.5 : CMake minimum 3.16](https://github.com/neovim/neovim/blob/v0.12.5/CMakeLists.txt)
- [Neovim v0.12.0 : mêmes prérequis de build](https://github.com/neovim/neovim/blob/v0.12.0/BUILD.md)
- [Neovim : dépendances bundled et options par défaut](https://github.com/neovim/neovim/blob/v0.12.5/cmake.deps/CMakeLists.txt)
- [Artefacts Neovim 0.12.0](https://github.com/neovim/neovim/releases/tag/v0.12.0), [0.11.7](https://github.com/neovim/neovim/releases/tag/v0.11.7), [0.10.4](https://github.com/neovim/neovim/releases/tag/v0.10.4)
- [Neovim : note sur la compilation croisée](https://github.com/neovim/neovim/blob/v0.12.5/BUILD.md#cross-compiling)
- [Tree-sitter v0.26.1 : assets publiés](https://github.com/tree-sitter/tree-sitter/releases/tag/v0.26.1)
- [Tree-sitter v0.26.1 : Rust minimum 1.84](https://raw.githubusercontent.com/tree-sitter/tree-sitter/v0.26.1/Cargo.toml)
- [Index BaseOS OL8 x86_64](https://yum.oracle.com/repo/OracleLinux/OL8/baseos/latest/x86_64/index.html)
- [Index AppStream OL8 x86_64](https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/index.html)
- [Index CodeReady Builder OL8 x86_64](https://yum.oracle.com/repo/OracleLinux/OL8/codeready/builder/x86_64/index.html)
- [Oracle : dépôts de développement OL8 et statut de support](https://docs.oracle.com/en/operating-systems/oracle-linux/8/distro-builder/distro-builder-GeneralRequirements.html)
