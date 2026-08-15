# Socle classpath jdtls — design

Date : 2026-08-15
Statut : validé, prêt pour plan d'implémentation

## Objectif

Rendre jdtls fiable sur les quatre types de projets Java rencontrés, pour que
la complétion, les diagnostics et la navigation soient corrects **avant**
d'ajouter le débogueur, le runner de tests et les refactorings.

Ce socle ne se voit pas à l'usage. Il conditionne tout le reste : sans
classpath correct, ni le DAP ni le runner de tests ne peuvent fonctionner.

## Contexte

C'est le sous-projet 1 d'une poussée en trois temps visant à se passer
d'IntelliJ :

1. **Socle classpath** (ce document)
2. Débogueur (nvim-dap + java-debug-adapter) et runner de tests
3. Refactorings et navigation lourde (hiérarchies, décompilation)

Types de projets à couvrir, par ordre de fréquence réelle :

- Outil de build Ant propriétaire, dépendances dans un dossier `lib/`
  (majoritaire, en cours de migration vers Maven)
- Maven multi-modules
- Maven mono-module
- Gradle
- Java legacy sans outil de build

## Constat vérifié

Mesuré sur `~/src/tsp-solver` (Maven mono-module, dépendance externe flatlaf) :
jdtls démarre, `root_dir` correct, zéro diagnostic. **Le mono-module Maven
fonctionne déjà.** Les cinq points ci-dessous sont ce qui reste.

| # | Problème | Preuve |
|---|---|---|
| 1 | `find_root` renvoie le marqueur le plus **proche**, pas le plus haut | `nvim-jdtls/lua/jdtls/setup.lua:37-44` — la boucle remonte et `return` au premier marqueur trouvé. Sur un multi-module, ouvrir `modA/src/main/java/Foo.java` donne `root=modA` au lieu de la racine réacteur : la navigation inter-modules ne résout pas |
| 2 | `workspace_dir` dérive de `vim.fn.getcwd()`, pas du root résolu | `init.lua:643`. Deux projets de même basename partagent le même workspace jdtls ; lancer nvim depuis un sous-dossier crée un workspace parasite |
| 3 | Aucun `java.configuration.runtimes` déclaré | `init.lua:648-683`. jdtls compile avec sa propre JVM quel que soit le `maven.compiler.target` du pom |
| 4 | `build.xml` absent des marqueurs de root | `init.lua:646`. Sur les projets Ant, `find_root` remonte jusqu'au `.git`, souvent bien au-dessus de la racine réelle du projet |
| 5 | `referencedLibraries` jamais configuré | Le mode invisible-project de jdtls gère les jars de `lib/`, mais il ne s'active que si le root est correct — donc dépend entièrement de (4) |

(2) et (4) sont des bugs francs. (1) est le plus coûteux : c'est lui qui rend
le multi-module inutilisable.

## Décisions actées

**Layout : `ftplugin/java.lua`.** C'est la convention documentée par
nvim-jdtls. Neovim source le fichier à chaque buffer Java, ce qui remplace
exactement l'`autocmd FileType java` actuel — même sémantique, moins de code.
Décidé maintenant plutôt qu'au sous-projet 3 : le DAP ajoutera
`init_options.bundles` et une douzaine de keymaps dans un `on_attach`, et un
`init.lua` de 1000 lignes deviendrait pénible à ce moment-là.

**JDK : cible 25 uniquement.** Un seul runtime, pas de découverte multi-JDK.
Le point (3) n'est donc pas traité dans ce sous-projet. Si un projet Ant
legacy remonte des erreurs d'API, la parade est un bloc
`settings.java.configuration.runtimes` de six lignes déclarant le JDK 8 déjà
installé sur la machine — aucune installation supplémentaire requise. Rien
n'est construit à l'avance pour ce cas.

**Validation : trois fixtures dont deux fabriquées.** Aucun projet Ant n'est
disponible sur cette machine ; on en fabrique un représentatif plutôt que de
livrer du code non testé.

## Design

### 1. Layout

Le bloc Java quitte `init.lua` pour `ftplugin/java.lua` :

- `init.lua` perd l'`autocmd FileType java` (~45 lignes) et ne conserve que la
  déclaration du plugin `mfussenegger/nvim-jdtls`
- `ftplugin/java.lua` reçoit la détection de root, le calcul de workspace et
  l'appel à `jdtls.start_or_attach`

Les deux scripts d'export offline copient `init.lua` **nommément**, pas le
dépôt : `export-offline.sh:47` (`cp init.lua "$EXPORT_DIR/config/"`, puis
`:140` côté installation) et `scripts/build-offline.sh:44`
(`cp "$REPO_DIR/init.lua" "$DIST_DIR/init.lua"`). Le dossier `ftplugin/`
serait donc silencieusement absent du bundle offline, et Java cesserait de
fonctionner sur la machine cible sans aucun message.

Les deux scripts doivent copier `ftplugin/` en plus de `init.lua`, et
`install-offline.sh` doit le déposer dans `~/.config/nvim/ftplugin/`. C'est
le critère d'acceptation 7.

### 2. Détection du root

Une fonction remonte depuis le fichier et retient le marqueur le plus haut de
la **chaîne contiguë**, bornée par le dépôt git :

```lua
-- find_root de nvim-jdtls renvoie le marqueur le plus PROCHE : sur un
-- multi-module, ouvrir modA/src/Foo.java donne modA au lieu de la racine
-- réacteur. On remonte tant que la chaîne de marqueurs n'est pas rompue.
local function reactor_root(dir, marker, ceiling)
  local best
  while dir do
    if vim.uv.fs_stat(dir .. "/" .. marker) then
      best = dir
    elseif best then
      break -- chaîne rompue : deux projets distincts sous le même dépôt
    end
    if dir == ceiling then break end
    local parent = vim.fs.dirname(dir)
    if parent == dir then break end
    dir = parent
  end
  return best
end
```

La rupture de chaîne n'est pas un détail : sur un dépôt hébergeant
`projA/pom.xml` et `projB/pom.xml` sans pom agrégateur à la racine, on renvoie
`projA` et non la racine du dépôt.

Ordre d'essai des marqueurs, premier trouvé gagne :

1. `pom.xml`
2. `settings.gradle` puis `settings.gradle.kts`
3. `build.gradle`
4. `build.xml`
5. le dépôt git, en dernier recours

C'est cet ordre qui corrige (4) : `.git` n'est plus dans la même liste plate
que les marqueurs de build, il devient le repli.

Le plafond (`ceiling`) est le dossier contenant le `.git` le plus proche,
obtenu par `vim.fs.root(chemin_du_fichier, ".git")`. Si le fichier n'est dans
aucun dépôt git, le plafond est `$HOME`.

### 3. Workspace

La clé du workspace dérive du root résolu, plus de `getcwd()` :

```
~/.cache/jdtls/workspaces/<basename du root>-<8 premiers hex de sha256(root)>
```

Le basename garde le chemin lisible à l'œil ; le hash garantit que deux
projets homonymes ne partagent pas de workspace. Corrige (2).

### 4. Réglages jdtls

Le bloc `settings` existant est repris tel quel (`format`, `saveActions`,
`organizeImports`). Deux points à trancher sur pièces à l'implémentation :

- `java.project.referencedLibraries` : la valeur par défaut de jdtls couvre
  déjà `lib/**/*.jar`. Vérifier sur la fixture Ant. **N'ajouter la ligne que
  si le défaut ne suffit pas** — pas de configuration redondante.
- `java.configuration.updateBuildConfiguration` : laisser le défaut tant
  qu'aucun symptôme ne le justifie.

Pas de bloc `runtimes` (voir Décisions actées).

### 5. Validation

Trois fixtures, un script qui les exécute toutes :

| Fixture | Emplacement | Ce qu'elle prouve |
|---|---|---|
| `tsp-solver` | `~/src/tsp-solver` (réel) | Non-régression : `root_dir` inchangé, zéro diagnostic |
| Multi-module Maven | fabriquée | Bug (1) : `root_dir` = racine réacteur, et l'import d'une classe de `modB` depuis `modA` résout |
| Ant + `lib/` | fabriquée | Bugs (4)(5) : `root_dir` = dossier du `build.xml`, et le jar de `lib/` résout |

La fixture multi-module est un pom réacteur avec `<modules>modA</modules>` et
`<modules>modB</modules>`, `modA` déclarant une dépendance sur `modB` et
important une de ses classes.

La fixture Ant est un `build.xml` minimal, un `lib/flatlaf.jar` (copié depuis
`tsp-solver`) et une source qui importe `com.formdev.flatlaf.FlatDarkLaf`.

Le script démarre `nvim --headless` sur un fichier de chaque fixture, attend
que jdtls atteigne `ServiceReady`, puis vérifie `root_dir` et l'absence de
diagnostic. Il sort en erreur si l'une des trois échoue.

## Critères d'acceptation

1. Ouvrir un fichier de `modA` dans la fixture multi-module donne
   `root_dir` = racine réacteur, et l'import inter-modules ne produit aucun
   diagnostic
2. Ouvrir la source de la fixture Ant donne `root_dir` = dossier du
   `build.xml`, et l'import de FlatLaf ne produit aucun diagnostic
3. `tsp-solver` conserve zéro diagnostic et son `root_dir` actuel
4. Ouvrir nvim depuis un sous-dossier d'un projet donne le même
   `workspace_dir` que depuis sa racine
5. Le script de validation passe en une commande
6. `nvim --headless -c 'qa!'` démarre sans erreur
7. Les scripts d'export offline embarquent `ftplugin/`

## Hors périmètre

Traité aux sous-projets 2 et 3, pas ici :

- Débogueur : `nvim-dap`, `nvim-dap-ui`, bundles `java-debug-adapter`
- Runner de tests : bundle `vscode-java-test` ou `neotest-java`
- Refactorings : `extract_variable`, `extract_method`, rename projet
- Navigation lourde : hiérarchies d'appel et de type, décompilation de jars
- Keymaps Java et leur documentation dans le README
- Déclaration multi-JDK (`java.configuration.runtimes`)

## Risques et hypothèses

**Le mode invisible-project de jdtls couvre le cas Ant.** C'est l'hypothèse
centrale, et elle n'est pas vérifiée : aucun projet Ant n'était disponible sur
la machine au moment du design. La fixture fabriquée la testera. Si elle
tombe, le repli est `java.project.referencedLibraries` explicite, et à défaut
la génération d'un `.classpath` Eclipse depuis les métadonnées de l'outil
propriétaire — ce qui serait un sous-projet à part entière.

**La fixture Ant fabriquée peut ne pas représenter l'outil propriétaire réel.**
Elle teste le mécanisme jdtls (invisible-project + jars de `lib/`), pas les
particularités de l'outil. Une validation sur un vrai projet reste à faire
côté machine de travail.

**Gradle n'est pas installé sur cette machine.** jdtls embarque sa propre
distribution Gradle et sait utiliser le wrapper, donc le cas devrait tenir,
mais il ne sera pas couvert par les fixtures.

## Défaut adjacent, hors périmètre

Découvert en vérifiant le point sur l'export offline. **La chaîne offline est
déjà cassée par la refonte v2, indépendamment de ce sous-projet :**

- `scripts/build-offline.sh:47` et `:52` appliquent des `sed` sur
  `auto_install = true` et `ensure_installed = {...}`. Ces deux motifs ont
  disparu d'`init.lua` avec le passage à la branche `main` de treesitter
  (`grep -c` renvoie 0 pour les deux). Les `sed` ne matchent rien et
  réussissent silencieusement — le bundle produit garde donc une config qui
  tente de télécharger les parsers au démarrage, ce qui est précisément ce que
  le mode offline doit empêcher.
- `scripts/offline-tsconfig.lua:43` fait `require("nvim-treesitter.configs")`,
  module qui n'existe pas sur la branche `main`. Le script sort en erreur.

À traiter séparément : ça ne touche ni jdtls ni le classpath, et le mélanger
au socle Java brouillerait les deux sujets.
