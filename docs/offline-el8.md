# Bundle OL8 / RHEL 9 avec Java et Python

La recette `scripts/export-offline-el8.sh` compile Neovim **0.12.5** dans
Oracle Linux 8 x86_64 avec ses dépendances privées. Elle réutilise les parsers,
queries et plugins de l'archive Linux existante, restaure lazy.nvim au commit
du dépôt, puis ajoute les outils Java/Python. L'archive finale n'est publiée
dans `dist/` qu'après les tests sur OL8 et UBI 9.

## Construire

Prérequis du poste de build : Docker Linux fonctionnel, réseau, Bash, Python 3.9+,
Git, curl, tar avec gzip/xz et `sha256sum`. La recette est validée depuis WSL.
La cible est x86_64 ; ARM n'est pas couvert par cette recette.

```bash
# Si l'archive Linux source n'existe pas encore :
scripts/export-offline-linux.sh

scripts/export-offline-el8.sh
# Ou fournir explicitement une archive Linux issue de cette configuration :
scripts/export-offline-el8.sh /chemin/nvim-config-offline-linux-x86_64.tar.gz
# Résultat : dist/nvim-config-offline-el8-x86_64.tar.gz et .sha256
```

`JOBS=4` règle le parallélisme de compilation. Docker conserve les couches de
build ; `${XDG_CACHE_HOME:-$HOME/.cache}/nvim-config/downloads/` conserve
les téléchargements des outils, dont les
SHA-256 sont revérifiés. Le digest OL8, le tag/source Neovim et les outils
sont épinglés. Les RPM résolus sont enregistrés, mais les dépôts DNF ne sont
pas un snapshot : la reconstruction n'est pas garantie identique bit à bit.

## Télécharger et stocker

Les archives qualifiées et leur SHA-256 sont publiés dans les
[GitHub Releases](https://github.com/cmoron/nvim-config/releases). Le dépôt Git
contient les sources et recettes ; les binaires restent hors Git, sans Git LFS.
`dist/` ne conserve que le livrable courant et son checksum. Les anciennes
versions restent téléchargeables depuis leur release ; ne pas remplacer les
assets d’une version publiée. Les archives source de build et les JDK de test
peuvent être conservés sous `~/.cache/nvim-config/`.

Le bundle exclut les tests/CI des plugins, les headers et gestionnaires de
paquets Node, les sourcemaps JS et les configurations jdtls des autres OS.
Il conserve les licences/notices, les stubs Python et le JDK complet, notamment
`src.zip` pour la navigation Java et ses caches CDS pour le démarrage.

## Installer et utiliser

```bash
sha256sum -c nvim-config-offline-el8-x86_64.tar.gz.sha256
tar -xzf nvim-config-offline-el8-x86_64.tar.gz
./nvim-config-offline/install.sh
export PATH="$HOME/.local/bin:$PATH"
nvim
```

L'installation et l'utilisation ne demandent ni root ni réseau. Le lanceur
`~/.local/bin/nvim` emploie le runtime embarqué et ajoute les outils au PATH
de Neovim et de ses processus enfants. Il ne modifie pas les fichiers du shell
ni le Java/Node global. Les outils sont installés sous
`~/.local/share/nvim-tools`, avec sauvegarde de l'ancien dossier.
Les notices complémentaires restent sous `~/.local/share/nvim/licenses/`.

| Composant             | Version / rôle                                                            |
| --------------------- | ------------------------------------------------------------------------- |
| Neovim                | 0.12.5, compilé avec GCC 8 sur OL8                                        |
| Plugins               | commits de `lazy-lock.json` ; parsers et blink réutilisés après réception |
| Temurin JDK           | 25.0.4.1+1, exécution de jdtls et bibliothèque standard Java 25           |
| jdtls                 | release 1.61.0 du 3 septembre 2026, épinglée                              |
| java-debug, java-test | versions contenues dans l'archive source                                  |
| Node                  | 24.18.0, runtime privé de Pyright                                         |
| Pyright               | 1.1.411, diagnostics et navigation Python                                 |
| Ruff                  | 0.16.8, serveur LSP et formatter Python                                   |

Le lanceur définit `JDTLS_JAVA_HOME` et `JAVA25_HOME` si ces variables ne sont
pas déjà renseignées. Pour un autre JDK serveur, définir `JDTLS_JAVA_HOME`.
Pour les projets Java 8 à 25, fournir le JDK correspondant et la variable
`JAVA8_HOME`, `JAVA11_HOME`, `JAVA17_HOME`, `JAVA21_HOME`, etc. Toutes les
variables `JAVA<version>_HOME` de 8 à 25 sont reconnues. Le JDK 25 du serveur
ne remplace pas les bibliothèques d'un ancien JDK cible. Le lanceur conserve
le `JAVA_HOME` et le `java` du PATH du projet ; seul jdtls utilise le JDK 25
embarqué. Les JDK de projet 8/11/17/21 ne sont pas inclus dans l'archive.

Pyright et Ruff peuvent analyser notre exemple sans interpréteur Python sur
la machine. **L'interpréteur, le `.venv` et les dépendances de tes projets
restent à provisionner** ; la configuration sélectionne `.venv/bin/python`
quand il existe. Les dépendances Maven/Gradle et leurs caches ne sont pas
incluses non plus. Un serveur LSP fonctionnel ne rend pas un projet tiers
compilable hors ligne sans ses dépendances.

## Réception et traçabilité

```bash
scripts/test-offline-linux.sh dist/nvim-config-offline-el8-x86_64.tar.gz oraclelinux:8
scripts/test-offline-linux.sh dist/nvim-config-offline-el8-x86_64.tar.gz registry.access.redhat.com/ubi9/ubi:9.6
```

Chaque test utilise un utilisateur non privilégié, sans réseau, une racine
en lecture seule et un HOME temporaire. Il vérifie les 23 parsers configurés,
les queries, blink Rust et les réponses LSP sur des projets Java/Python
temporaires. Les tests LSP attendent les diagnostics et les réponses hover ;
ils ne certifient pas le debug Java, JUnit ou l'import Maven/Gradle.

`build-info/` dans l'archive contient les versions RPM, le manifeste des
sources, les SHA-256, les dépendances Neovim, les informations ELF et la
recette Docker. `licenses/` et `build-info/source-notices.txt` ajoutent les
notices et la provenance des composants compilés. Le SHA de l'archive source identifie les extensions Java et
les binaires réutilisés. Git, rg/fd, lazygit et les LSP des autres langages
ne sont pas embarqués. Un test UBI 9 ne remplace pas la réception finale sur
ta machine RHEL et tes projets.

Pour rejouer la matrice des projets Java LTS, fournir un répertoire contenant
les JDK sous `8/`, `11/`, `17/`, `21/` (le 25 vient du bundle) :

```bash
TEST_JDKS=/chemin/jdks scripts/test-offline-linux.sh dist/nvim-config-offline-el8-x86_64.tar.gz oraclelinux:8
```

Le test Java 8 vérifie notamment `javax.xml.bind.DatatypeConverter`, absent
des JDK récents : cela détecte une utilisation accidentelle du JDK serveur
comme bibliothèque du projet. Chaque version teste un diagnostic de type,
un hover et la disparition de l'erreur après correction du code.
