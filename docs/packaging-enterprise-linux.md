# Packaging offline Enterprise Linux

État de l'étude : 19 septembre 2026. Périmètre : installation sans privilège
root ni réseau, architecture x86_64. Le bundle Fedora a maintenant été construit
et testé en conteneurs Fedora 43, Oracle Linux 8.10 et UBI 9.6. Une recette EL8 dédiée existe désormais : voir le
[guide du bundle OL8 Java/Python](offline-el8.md). Les résultats Fedora
ci-dessous restent ceux de l'archive initiale, distincte de l'archive EL8.

## Bundle EL8 qualifié le 19 septembre

Archive : `dist/nvim-config-offline-el8-x86_64.tar.gz`. La taille et le SHA-256
du livrable sont publiés dans la [release GitHub](https://github.com/cmoron/nvim-config/releases) ;
le fichier `.sha256` adjacent permet de vérifier le transfert. Les mesures
précédant le nettoyage (307 464 386 octets) ne décrivent plus le livrable final.

Neovim 0.12.5 a été compilé avec GCC 8.5.0 et CMake 3.26.5 sur OL8 ; son
ELF requiert au maximum glibc 2.28. Le bundle contient les 22 plugins au lock
courant, 24 parsers (23 configurés + dtd), blink Rust, jdtls 1.61.0,
Temurin 25.0.4.1, Node 24.18.0, Pyright 1.1.411 et Ruff 0.16.8.
Le JDK du serveur jdtls est distinct de celui du projet ; le lanceur conserve
le JAVA_HOME et le java du PATH de l'utilisateur.

| JDK du projet | OL8.10, glibc 2.28 | UBI 9.6, glibc 2.34 |
| --- | --- | --- |
| Temurin 8u504-b01 | PASS | PASS |
| Temurin 11.0.32.1+1 | PASS | PASS |
| Temurin 17.0.20.1+1 | PASS | PASS |
| Temurin 21.0.12.1+1 | PASS | PASS |
| Temurin 25.0.4.1+1 | PASS | PASS |

Sur les deux OS : les 23 parsers et leurs queries, blink Rust, les diagnostics
Pyright/Ruff et le hover Python passent. Pour chaque JDK : un hover Java, un
diagnostic de type et sa disparition après correction passent ; Java 8 vérifie
aussi une API JAXB absente du JDK 25. Les autres versions entre 8 et 25 sont
configurables, mais n'ont pas été exécutées dans cette matrice.

La réception utilise UID/GID 10001, `--network none`, une racine en lecture
seule et un HOME temporaire. Reproduction :

```bash
TEST_JDKS="$HOME/.cache/nvim-config/test-jdks" scripts/export-offline-el8.sh \
  "$HOME/.cache/nvim-config/nvim-config-offline-linux-x86_64.tar.gz"
```

Les JDK de test 8/11/17/21 se trouvent sous `~/.cache/nvim-config/test-jdks/` et ne sont pas
embarqués. Le guide explique comment fournir ses propres JDK pour rejouer
la matrice. Sans `TEST_JDKS`, l'export vérifie le projet Java 25, Python et le
socle natif sur les deux OS. Les digests de réception sont ceux listés plus
bas ; logs complets : `logs/docker-build-el8.log`. Les fichiers de configuration,
le lock, l'installeur et les scripts de contrôle de l'archive ont été comparés
aux sources courantes ; le SHA-256 a été recalculé après publication locale.

ShellCheck, StyLua, les **14 tests de packaging** et la revue indépendante
passent. L'installeur sauvegarde le runtime, le lanceur, la configuration, les
plugins et les outils avant remplacement. La release jdtls et le JDK serveur
sont épinglés pour éviter le changement implicite de minimum Java observé
avec le snapshot Eclipse. Pyright utilise son mode push natif pour éviter une
course des diagnostics pull reproduite avec Neovim 0.12.5.

Cela qualifie le socle et les LSP sur ces projets minimaux. Les projets réels,
leurs dépendances Maven/Gradle/Python, le debug Java/JUnit et les hôtes physiques
OL8/RHEL restent à réceptionner. Le [guide d'utilisation](offline-el8.md)
détaille le contenu et les variables de JDK.

## Archive Fedora initiale du 18 septembre

Archive : `dist/nvim-config-offline-linux-x86_64.tar.gz` (~90 Mio), avec Neovim
v0.12.5, 22 plugins verrouillés, 23 parsers configurés et le parser `dtd`
supplémentaire requis par XML, ainsi que jdtls/debug/tests sans JDK.

| Cible réelle                             | Résultat pour l'archive Fedora                         |
| ---------------------------------------- | ------------------------------------------------------ |
| Fedora 43 x86_64                         | Installation, 23 parsers/queries et fuzzy Rust validés |
| UBI 9.6 x86_64 (base RHEL 9), glibc 2.34 | Même test complet validé                               |
| Oracle Linux 8.10 x86_64, glibc 2.28     | Refus de l'installation : runtime Neovim incompatible  |

Tests sous UID/GID 10001, `--network none`, `--read-only` et HOME dans un
tmpfs. Aucun Neovim ni plugin hôte n'est utilisé. Git est absent des images de
réception : gitsigns le signale comme attendu. Git, LSP externes, formatters
et JDK restent à provisionner ; cette recette valide le socle éditeur, pas
Java/DAP ou un environnement de développement entièrement autoporteur.
UBI n'est pas un test sur un hôte RHEL abonné ni sur les projets de travail.

Rejouer, avec les images disponibles dans Docker :

```bash
bash scripts/test-offline-linux.sh
bash scripts/test-offline-linux.sh dist/nvim-config-offline-linux-x86_64.tar.gz registry.access.redhat.com/ubi9/ubi:9.6
bash scripts/test-offline-linux.sh dist/nvim-config-offline-linux-x86_64.tar.gz oraclelinux:8 # échec attendu
```

SHA-256 de l'archive testée :
`0f399372bd83686d20fbae29fd17967dfa13c22ac591231fa781da13805b8bb8`.
Le fichier `.tar.gz.sha256` adjacent permet de vérifier un transfert.

Images testées (digests de registre) :

- `fedora@sha256:a651ddf48ea28a06ed4e1e6519f51c9f47e7a5a138722ade87369b8fbb7e5b42`
- `registry.access.redhat.com/ubi9/ubi@sha256:dec374e05cc13ebbc0975c9f521f3db6942d27f8ccdf06b180160490eef8bdbc`
- `oraclelinux@sha256:21916d0f9527aa5d0b84034dcb3f6d2f01b59e633e31221b49855032ce41069a`

## Décision

Un bundle unique `el8-x86_64` est réaliste pour Oracle Linux 8 et RHEL 9, à
condition de le construire dans l'environnement le plus ancien : Oracle Linux
8 (ou UBI 8), puis en qualifiant toutes les bibliothèques natives distribuées.
Il se décompresserait sous `$HOME`, avec `bash`, `tar`, `gzip`, un HOME
inscriptible et les bibliothèques de base EL8/EL9 validées. Le chargeur glibc
système reste un prérequis ; « autoporteur » ne signifie pas statique.

Le bundle Linux générique actuel n'est pas ce bundle : il construit dans
`fedora:43` et télécharge le tarball Neovim officiel. Le 18 septembre, le
tarball officiel `nvim-linux-x86_64` v0.12.5 demande `GLIBC_2.34` (vérifié par
`readelf --version-info`). Oracle Linux 8 fournit glibc 2.28 : il ne peut donc
pas démarrer ce runtime. RHEL 9 fournit bien cette génération de glibc, mais
les parsers compilés dans Fedora 43 ne sont pas pour autant une promesse de
portabilité générale vers RHEL 9. Cette archive précise passe toutefois la
recette sur UBI 9.6 ci-dessus ; chaque reconstruction doit refaire ce test.

La solution minimale est donc un runtime Neovim 0.12.x compilé depuis les
sources dans le conteneur EL8, installé sous un préfixe du bundle. Le build
amont documente les prérequis RHEL/Fedora et un build statique musl, mais ce
dernier ne réduit pas la validation des modules `.so` ; le build EL8 dynamique
est le choix le plus simple pour cette configuration.

L'[évaluation de compilation OL8](neovim-ol8-build-evaluation.md) précise les
dépendances et compare les versions 0.10, 0.11 et 0.12 : conserver 0.12.5 est
le chemin le plus court. L'inspection ELF de l'archive actuelle ne montre pas
de blocage glibc dans les 24 parsers ni dans blink. Le premier pilote peut
donc remplacer seulement le runtime Neovim, puis tester leur réutilisation
sur OL8 ; il n'est pas encore nécessaire de tous les recompiler.

## Portée

| Cible                           | Bundle `el8-x86_64`                     | Validation à faire                                                                                           | Statut                 |
| ------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ---------------------- |
| Oracle Linux 8 x86_64           | Oui, cible de référence (glibc 2.28)    | Conteneur `oraclelinux:8` et hôte OL8 sans réseau                                                            | Conteneur validé ; hôte à tester |
| RHEL 9 x86_64                   | Oui, même archive EL8                   | Conteneur UBI 9 puis hôte RHEL 9 sans réseau                                                                 | UBI 9 validé ; hôte à tester |
| Oracle Linux 8 / RHEL 9 aarch64 | Possible, mais archive et build séparés | Image EL8 aarch64, JDK et Node aarch64                                                                       | Non testé              |
| ppc64le, s390x, autres          | Hors portée                             | Le script actuel ne mappe que amd64 et arm64 ; Neovim, JDK et plugins natifs doivent être qualifiés ensemble | Non supporté           |

UBI 9 est un bon environnement de validation RHEL 9 : Red Hat le distribue
comme image OCI librement redistribuable et maintenue. Ce n'est pas une
substitution à un test sur l'image RHEL abonnée si des paquets hors des dépôts
UBI sont nécessaires.

## Matrice des composants

| Composant         | Minimum portable sans réseau                                                                                                                                                             | Point ABI / exploitation                                                                                                                                                                                                                                        |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Neovim            | Compiler le tag exact 0.12.x dans EL8 ; embarquer tout l’arbre installé (`bin/`, `share/`, `lib/`) sous `$HOME/.local/share/neovim`                                                                                    | Les releases amont actuelles existent pour Linux x86_64 et arm64, mais v0.12.5 x86_64 requiert glibc 2.34 : ne pas les employer pour EL8.                                                                                                                       |
| `nvim-treesitter` | Copier parsers **et** queries du commit verrouillé ; tester ceux du bundle actuel, puis reconstruire dans EL8 si nécessaire                                                                                            | La branche `main` exige Neovim >= 0.12, ABI Tree-sitter >= 13, `tree-sitter-cli` >= 0.26.1 et un compilateur au build. Aucun de ces outils n'est requis sur la cible si les `.so` sont embarqués.                                                               |
| `blink.cmp`       | Copier le `.so` GNU/Linux correspondant à la version du plugin et son checksum                                                                                                           | blink v1.10.2 présent dans le lock expose `GLIBC_2.17` (mesuré sur le binaire local) ; l'amont publie des binaires glibc pour x86_64 et aarch64 et prévoit le repli Lua. Vérifier malgré tout `ldd -v` dans OL8 et RHEL9 pour chaque release.                   |
| Node et LSP npm   | Facultatif pour l'éditeur ; nécessaire pour pyright, bashls, ts_ls et Svelte : embarquer Node 24 LTS et un préfixe de packages JS complet (installation via Bun) sous `$HOME/.local/opt` | Node 20, indiqué dans le README avant cette revue, est EOL depuis le 24 mars 2026. Les binaires Node officiels x64 et arm64 supportent glibc >= 2.28, donc EL8. Les dépendances npm doivent être installées et verrouillées au build, pas au premier lancement. |
| Java / jdtls      | Facultatif hors Java ; pour Java, embarquer un JDK 25 de la bonne architecture, jdtls et les jars debug/tests sous `$HOME/.local`                                                        | Le bundle qualifie jdtls 1.61.0 avec Java 25 ; certaines dépendances Eclipse exigent déjà Java 25. Le JDK qui lance jdtls peut rester distinct des JDK de projets (`JDTLS_JAVA_HOME`, `JAVA8_HOME`, etc.).                                                                                                                       |
| Outils externes   | `rg` et `fd` restent optionnels ; lazygit, ruff, rust-analyzer, gopls, formatters et CLI divers ne font pas partie du core                                                               | Les ajouter seulement dans des modules explicites par langage : leurs binaires et licences sont indépendants de Neovim.                                                                                                                                         |

Ainsi, « autoporteur » doit désigner deux niveaux distincts :

1. **core** : Neovim, configuration, plugins verrouillés, parsers, queries et
   blink ; l'éditeur démarre immédiatement hors ligne.
2. **dev** : core + Node/LSP npm + JDK/jdtls. Il est aussi sans réseau ni root,
   mais son contenu est plus lourd et doit être verrouillé par version et
   architecture.

Éviter un troisième niveau qui tenterait d'embarquer tous les formatters et
LSP : les outils réellement utilisés peuvent être ajoutés comme modules, avec
leurs propres tests, plutôt que de gonfler chaque installation.

## Construction et réception

La recette EL8 épingle l'image OL8 par digest, Neovim, le JDK, Node, jdtls,
Pyright et Ruff, et génère un manifeste des sources et SHA-256. Les plugins
suivent `lazy-lock.json`. Les extensions Java et parsers proviennent du seed
Linux, identifié par son SHA-256 ; leurs sources/notices sont inventoriées.
Le build initial du seed utilise encore Fedora sans digest et les URLs
Marketplace `latest`. Les dépôts RPM ne sont pas figés : cette recette n'est
pas une reconstruction reproductible bit à bit.

La réception exécute l'installation puis les contrôles du bundle en conteneurs
OL8 et UBI 9 sans réseau et sans privilèges. Elle couvre parsers/queries,
blink Rust, diagnostics/hover Python et Java. Le lanceur sélectionne Neovim et
Node privés, et réserve le JDK 25 au serveur jdtls ; il préserve le Java du
projet dans le PATH et `JAVA_HOME`.

Le marqueur actuel `PLATFORM` ne contient que `Linux x86_64`. Il protège contre
une mauvaise architecture, pas contre une glibc trop récente : le manifeste et
le nom de l'archive doivent annoncer `el8-x86_64`.

## Licences et traçabilité

L'archive est une collection de logiciels tiers, pas un paquet système RPM.
Les licences/notices livrées avec les plugins, Node, Pyright, JDK et JAR sont
conservées. `licenses/` complète les notices de Neovim, de ses dépendances
compilées, de Ruff, de jdtls, des extensions Java et des grammaires embarquées.
`build-info/source-notices.txt` recense leurs sources et SHA-256 ; le manifeste
principal identifie le seed et les fichiers de configuration. Cet inventaire
n'est pas un SBOM standardisé ni une certification juridique.

## Sources primaires

- [Oracle Linux 8 : glibc 2.28 et Podman rootless](https://docs.oracle.com/en/operating-systems/oracle-linux/8/relnotes8.0/ol8-NewFeaturesandChanges.html)
- [Images Oracle Linux et tags de conteneurs](https://docs.oracle.com/en/operating-systems/oracle-linux/podman/registries.html)
- [Universal Base Image 9 : conditions et image maintenue](https://catalog.redhat.com/en/software/containers/ubi9/618326f8c0d15aff4912fe0b)
- [RHEL 9 : paquet glibc 2.34](https://access.redhat.com/solutions/7126407)
- [Neovim : releases Linux et avertissement glibc](https://github.com/neovim/neovim/releases)
- [Neovim : build RHEL/Fedora et build statique musl](https://neovim.io/doc/build/)
- [nvim-treesitter `main` : exigences et compatibilité des parsers](https://github.com/nvim-treesitter/nvim-treesitter)
- [blink.cmp v1.10.2 : binaires glibc et repli Lua](https://github.com/Saghen/blink.cmp/blob/v1.10.2/doc/configuration/fuzzy.md)
- [Node.js : plateformes x64/arm64, glibc 2.28 et RHEL 8](https://github.com/nodejs/node/blob/main/BUILDING.md)
- [Node.js : calendrier des versions, Node 20 EOL](https://nodejs.org/en/about/previous-releases)
- [Eclipse JDT LS : exigences du serveur](https://github.com/eclipse-jdtls/eclipse.jdt.ls)
