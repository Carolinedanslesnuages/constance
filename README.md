# Constance

Les mêmes règles de pull request dans tous vos dépôts, maintenues à un seul endroit.

Constance regroupe six contrôles GitHub Actions, faits pour des dépôts où une partie du code
est écrite par des assistants de code :

| Contrôle | Ce qu'il vérifie |
|---|---|
| [Taille des fichiers](#taille-des-fichiers) | Un fichier, une responsabilité : pas de fichier de code ou de test trop long. |
| [Titre de PR](#titre-de-pr) | Le titre suit Conventional Commits, pour que les versions soient calculées juste. |
| [Nommage des fichiers](#nommage-des-fichiers) | Les fichiers ajoutés s'écrivent en kebab-case, les composants Vue en PascalCase. |
| [Variables d'environnement](#variables-denvironnement) | Chaque variable lue par le code est déclarée dans `.env.example`. |
| [Motifs dangereux](#motifs-dangereux) | Aucun motif connu pour ouvrir une faille (TLS désactivé, CORS ouvert, HTML injecté, SQL assemblé, erreur avalée). |
| [Anti-fuite](#anti-fuite) | Aucun secret (clé, jeton, mot de passe) n'entre dans le dépôt. |

## Installation

Copiez [`exemples/constance.yml`](exemples/constance.yml) dans `.github/workflows/` de votre
projet :

```yaml
name: Constance

on:
  pull_request:
    types: [opened, edited, synchronize, reopened]

permissions:
  contents: read

jobs:
  titre:
    name: Titre de PR (Conventional Commits)
    runs-on: ubuntu-latest
    steps:
      - uses: Carolinedanslesnuages/constance/titre-pr@v1

  taille:
    name: Taille des fichiers (une responsabilité par fichier)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7.0.1
      - uses: Carolinedanslesnuages/constance/taille-fichiers@v1

  nommage:
    name: Nommage des fichiers (kebab-case, PascalCase.vue)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7.0.1
      - uses: Carolinedanslesnuages/constance/nommage-fichiers@v1

  variables-env:
    name: Variables d'environnement (.env.example)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7.0.1
      - uses: Carolinedanslesnuages/constance/variables-env@v1

  motifs:
    name: Motifs dangereux (TLS, CORS, HTML, SQL, erreurs)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7.0.1
      - uses: Carolinedanslesnuages/constance/motifs-dangereux@v1

  anti-fuite:
    name: Anti-fuite (gitleaks)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7.0.1
        with:
          fetch-depth: 0
      - uses: Carolinedanslesnuages/constance/anti-fuite@v1
```

Gardez les contrôles que vous voulez : chacun est indépendant. Pour qu'ils bloquent la fusion,
déclarez-les comme contrôles requis dans la protection de la branche principale.

`@v1` suit les corrections et nouveautés compatibles. Pour figer une version précise, utilisez
son numéro (`@v1.0.0`) ou l'empreinte de son commit.

## Taille des fichiers

Un fichier de code ne dépasse pas **400 lignes non vides**, un fichier de test **600**. Au-delà,
il porte probablement plusieurs responsabilités : on le découpe, chaque partie dans un fichier
qui dit ce qu'elle fait.

- **Fichiers existants** : un fichier déjà trop long est toléré tant qu'il ne grossit pas,
  même renommé ou déplacé. On le découpe quand on y travaille.
- **Alerte avant la limite** : à partir de 90 % de la limite, un avertissement apparaît dans
  la PR.
- **Résumé** : un tableau des fichiers concernés s'affiche dans le résumé du contrôle.
- Seuls les fichiers modifiés par la PR sont lus. Les lignes vides ne comptent pas.

| Réglage | Par défaut | Rôle |
|---|---|---|
| `max-code` | `400` | Lignes non vides maximum pour un fichier de code. |
| `max-test` | `600` | Lignes non vides maximum pour un fichier de test. |
| `seuil-avertissement` | `90` | Pourcentage de la limite qui déclenche l'alerte. |
| `extensions` | `ts tsx js jsx mjs cjs mts cts vue py` | Extensions comptées. |
| `exclusions` | `*/migrations/* *.d.ts *.min.js` | Motifs ignorés. |
| `motifs-test` | `*.spec.* *.test.* */tests/* */test/* */__tests__/* */test_*.py *_test.py` | Motifs des fichiers de test. |

Exemple pour un projet Go et Svelte, avec une limite plus basse :

```yaml
      - uses: Carolinedanslesnuages/constance/taille-fichiers@v1
        with:
          max-code: "300"
          extensions: "go svelte ts"
          motifs-test: "*_test.go *.spec.ts"
```

## Titre de PR

En fusion squash, le titre de la PR devient le commit de la branche principale. Les outils de
version (release-please, semantic-release) le lisent pour choisir la prochaine version : `feat`
donne une version mineure, `fix` un correctif, `!` un changement incompatible.

Le contrôle accepte les titres de la forme `type(portée facultative)!: description` :

```text
feat: ajouter l'export CSV
fix(api): corriger le tri par date
feat!: changer le format des adresses
```

- **Correction proposée** : un titre refusé reçoit une suggestion, par exemple
  « Corrige le bouton d'envoi » → « fix: corrige le bouton d'envoi ».
- **Bouton « Revert » de GitHub** : son titre `Revert "feat: …"` est accepté.
- **Robots** (Dependabot, Renovate…) : leurs titres non conformes ne bloquent pas. Configurez
  plutôt leur préfixe de commit.
- **Réglage de fusion** : voir ci-dessous.

| Réglage | Par défaut | Rôle |
|---|---|---|
| `types` | `feat fix perf refactor docs test build ci chore style revert` | Types autorisés. |
| `ignorer-bots` | `true` | Ne pas bloquer les PR des robots. |
| `verifier-reglage-squash` | `true` | Prévenir si le réglage de fusion peut ignorer le titre. |
| `rose` | `false` | Vérifier aussi l'emoji [Rose](https://github.com/Carolinedanslesnuages/rose) du titre (`feat: 🌸 …`). |

Avec `rose: "true"`, chaque titre doit porter l'emoji de son type (🌸 `feat`, 🐞 `fix`…). Si le
dépôt a sa propre liste (`.rose.json`), récupérez-le avant (`actions/checkout`) pour qu'elle soit
lue. Le hook Git de Rose ajoute l'emoji tout seul à chaque commit, sur votre ordinateur.

### Le réglage à faire sur chaque dépôt

Par défaut, quand une PR ne contient **qu'un seul commit**, GitHub utilise le message de ce
commit pour la fusion en squash, et non le titre de la PR. Le titre vérifié est alors ignoré.

Dans **Settings → General → Pull Requests**, cochez « Allow squash merging » et choisissez
**« Default to pull request title »**. En ligne de commande :

```sh
gh api -X PATCH repos/<compte>/<dépôt> \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY
```

Le contrôle prévient quand ce réglage n'est pas le bon, mais seulement si son jeton peut le
lire : le jeton par défaut d'un workflow n'en a généralement pas le droit.

## Nommage des fichiers

Les fichiers **ajoutés ou renommés** par la PR s'écrivent en `kebab-case` (minuscules et tirets),
les composants Vue en `PascalCase`. Un nom refusé reçoit une proposition :

```text
userService.ts      → user-service.ts
HTTPClient.spec.ts  → http-client.spec.ts
user-card.vue       → UserCard.vue
```

- **Noms existants** : tolérés tant qu'on ne les renomme pas. Un renommage vers un mauvais nom
  est refusé.
- Le nom vérifié est la partie avant le premier point : `user-service` dans
  `user-service.spec.ts`.
- Les fichiers cachés (`.eslintrc.cjs`…) suivent la convention de leur outil : ignorés.

| Réglage | Par défaut | Rôle |
|---|---|---|
| `extensions` | `ts tsx js jsx mjs cjs mts cts vue css scss` | Extensions vérifiées. |
| `exclusions` | `*/migrations/* */__tests__/* *.d.ts` | Motifs ignorés (les migrations portent souvent un horodatage et un nom de classe). |

## Variables d'environnement

Une variable d'environnement oubliée dans `.env.example` ne se voit qu'au premier lancement sur
une autre machine. Le contrôle lit les **lignes ajoutées** par la PR et vérifie que chaque
variable lue est déclarée dans `.env.example` :

```ts
process.env.DATABASE_URL
process.env['API_KEY']
import.meta.env.VITE_API_URL                        // Vite
this.configService.getOrThrow<string>('JWT_SECRET')  // NestJS
```

- Une déclaration s'écrit `NOM=valeur` (ou `export NOM=valeur`). Ajoutez un commentaire au-dessus
  qui dit à quoi elle sert.
- **Variables déjà lues avant la PR** : tolérées.
- **Tests** : ignorés par défaut, ils fixent souvent leurs propres variables.
- **Variables fournies par le système, Node, Vite ou GitHub** (`NODE_ENV`, `MODE`, `GITHUB_*`…) :
  ignorées.

| Réglage | Par défaut | Rôle |
|---|---|---|
| `fichier-exemple` | `.env.example` | Fichier qui déclare les variables. |
| `extensions` | `ts tsx js jsx mjs cjs mts cts vue` | Extensions lues. |
| `exclusions` | `*.spec.* *.test.* */test/* */tests/* */e2e/* */__tests__/*` | Motifs ignorés. |
| `ignorer` | `NODE_ENV CI HOME PATH PWD TZ LANG MODE DEV PROD SSR BASE_URL GITHUB_* RUNNER_*` | Variables à ne pas déclarer (motifs acceptés). |

## Motifs dangereux

Un agent écrit vite des motifs connus pour ouvrir une faille. Le contrôle les cherche dans les
**lignes ajoutées** par la PR (tests exclus) :

| Motif | Exemple | Effet |
|---|---|---|
| Vérification TLS désactivée | `rejectUnauthorized: false`, `verify=False` | 🔴 bloque |
| CORS ouvert à tous | `Access-Control-Allow-Origin: *`, `origin: '*'` | 🟠 avertit |
| HTML injecté | `innerHTML =` et `+=`, `v-html`, `dangerouslySetInnerHTML` | 🟠 avertit |
| SQL assemblé avec du texte | `"SELECT … FROM " + id`, `` `DELETE FROM … ${id}` ``, f-string Python | 🟠 avertit |
| Erreur avalée | `catch {}`, `except: pass` | 🟠 avertit |

Seul le TLS désactivé bloque : les autres motifs sont parfois légitimes (HTML nettoyé, `catch`
vide voulu). Chaque signalement est annoté sur sa ligne et explique le risque.

- **Exception voulue** : `constance: autorisé` en commentaire sur la ligne, avec la raison
  (`// constance: autorisé, contenu nettoyé par DOMPurify`). L'exception est écrite dans le
  code, à côté de ce qu'elle permet, et relue en PR.
- **Code déjà là** : une ligne qui existait déjà avant la PR (code déplacé ou réindenté) est
  tolérée.

**Ce que le contrôle ne voit pas** : c'est une recherche de motifs, ligne par ligne. Il ne voit
pas une requête SQL écrite sur plusieurs lignes, ni en minuscules (`select … from`), ni un `catch`
vide sur deux lignes, ni une valeur dangereuse qui arrive d'un autre fichier. Pour suivre les
données d'un bout à l'autre, activez **CodeQL** (analyse de code de GitHub, gratuite pour les
dépôts publics) ; Reine vérifie qu'il est activé.

| Réglage | Par défaut | Rôle |
|---|---|---|
| `extensions` | `ts tsx js jsx mjs cjs mts cts vue py` | Extensions lues. |
| `exclusions` | les tests (`*.spec.*`, `*.test.*`, `*/test/*`…) | Motifs ignorés. |

## Anti-fuite

[gitleaks](https://github.com/gitleaks/gitleaks) 8.30.1 cherche des secrets dans les commits.
Le binaire officiel est téléchargé et vérifié par son empreinte SHA-256 avant d'être lancé.

- Sur une PR, seuls **les commits de la PR** sont analysés. Ailleurs (push, lancement manuel),
  tout l'historique est analysé.
- Le dépôt doit être récupéré avec `fetch-depth: 0`.
- Un faux positif s'écarte avec un fichier `.gitleaks.toml` à la racine du projet, que
  gitleaks lit tout seul.

| Réglage | Par défaut | Rôle |
|---|---|---|
| `tout-l-historique` | `false` | Analyser tout l'historique même sur une PR. |

Pour vérifier avant même de commiter, ajoutez le hook [pre-commit](https://pre-commit.com) de
gitleaks à votre projet.

## Développer Constance

```sh
bash tests/run.sh
```

Les tests créent des dépôts git jetables et vérifient chaque cas : fichier trop long, fichier
existant toléré, renommé ou déplacé, seuils réglés, titres acceptés et refusés, suggestions,
robots, titre contenant une commande (jamais exécutée), noms de fichiers et propositions,
variables déclarées, oubliées, tolérées ou ignorées, motifs dangereux signalés ou acceptés
(faux positifs), exception écrite sur la ligne, code déjà présent toléré.

## Licence

[MIT](LICENSE).
