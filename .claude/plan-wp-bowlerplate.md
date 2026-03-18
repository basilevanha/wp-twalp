# Plan : WordPress Boilerplate Moderne (Timber + Vite + ACF)

## Contexte

**Problème :** Quand on développe un thème WordPress avec Timber, les fichiers de configuration dev (package.json, .gitignore, node_modules, etc.) se retrouvent dans le dossier du thème (`wp-content/themes/mon-theme/`). Cela pollue le thème et le repo git avec des fichiers qui n'ont rien à voir avec WordPress.

**Objectif :** Créer un boilerplate où le **code source** (templates Twig, SCSS, JS, config) vit à la racine du projet git, et un **système de build** compile/copie le thème dans l'installation WordPress. Le repo git ne contient que le code source, jamais l'installation WP.

**Résultat attendu :** Un développeur clone le repo, lance `npm run setup`, puis `npm run dev`, et il a un WordPress local fonctionnel avec HMR.

---

## Structure des dossiers

> **NOTE :** La structure des templates Twig a légèrement changé par rapport au plan initial.
> Le plan prévoyait `src/templates/` avec les fichiers à plat (base.twig, index.twig, partials/).
> En réalité, on a gardé la structure Timber originale avec des sous-dossiers :
> `src/templates/layouts/`, `src/templates/templates/`, `src/templates/partials/`.
> C'est plus fidèle à Timber et évite de modifier les chemins dans les fichiers PHP.

```
wp-boilerplate/
├── bin/
│   ├── setup.sh                 # CLI interactif de configuration ✅
│   ├── sync.js                  # Script de copie src/ → thème WP ✅
│   └── dev.js                   # Orchestrateur dev (sync + vite + banner + cleanup) ✅
├── database/                    # Dumps SQL optionnels ✅
│   └── .gitkeep
├── docker/
│   └── docker-compose.yml       # WordPress + MySQL + phpMyAdmin ✅
├── src/                         # === ESPACE DE TRAVAIL DU DEV ===
│   ├── acf-json/                # ACF field groups (versionné dans git) ✅
│   ├── fonts/                   # Polices custom ✅ (dossier vide)
│   ├── images/                  # Images du thème ✅ (dossier vide)
│   ├── js/
│   │   └── main.js              # Point d'entrée JS ✅
│   ├── scss/
│   │   ├── main.scss            # Point d'entrée SCSS ✅
│   │   ├── _variables.scss      # ✅
│   │   ├── base/
│   │   │   ├── _reset.scss      # ✅
│   │   │   └── _typography.scss # ✅
│   │   ├── components/          # ✅ (vide)
│   │   └── layouts/             # ✅ (vide)
│   ├── templates/               # Templates Twig (Timber)
│   │   ├── layouts/
│   │   │   └── base.twig        # ✅
│   │   ├── templates/
│   │   │   ├── 404.twig         # ✅
│   │   │   ├── archive.twig     # ✅
│   │   │   ├── author.twig      # ✅
│   │   │   ├── index.twig       # ✅
│   │   │   ├── page.twig        # ✅
│   │   │   ├── search.twig      # ✅
│   │   │   ├── single.twig      # ✅
│   │   │   └── single-password.twig # ✅
│   │   └── partials/            # ✅ (tous les partials Timber)
│   └── theme/                   # Fichiers PHP du thème
│       ├── functions.php        # ✅ (modifié : charge autoload-path.php + require StarterSite.php + inc/)
│       ├── index.php            # ✅
│       ├── style.css            # ✅
│       ├── screenshot.png       # ✅
│       ├── single.php           # ✅
│       ├── page.php             # ✅
│       ├── archive.php          # ✅
│       ├── author.php           # ✅
│       ├── search.php           # ✅
│       ├── 404.php              # ✅
│       ├── src/
│       │   └── StarterSite.php  # ✅ (nettoyé : retiré démo foo/bar/myfoo, text domain starter-theme)
│       ├── languages/           # ✅ Dossier traductions (.pot/.po/.mo)
│       │   └── .gitkeep
│       └── inc/
│           ├── vite.php         # ✅ Helper d'enqueue des assets Vite
│           ├── timber.php       # ✅ Configuration Timber
│           ├── acf.php          # ✅ Paths JSON ACF
│           ├── cleanup.php      # ✅ Nettoyage wp_head, emojis, etc.
│           └── i18n.php         # ✅ load_theme_textdomain()
├── public/                      # Installation WP (GITIGNORE) ✅
│   └── wp-content/themes/starter-theme/ # ← BUILD OUTPUT ✅
├── .env.example                 # ✅
├── .env                         # ✅ (gitignored)
├── .gitignore                   # ✅
├── composer.json                # ✅ Timber v2.3.3
├── package.json                 # ✅ Vite 6 + plugins
├── vite.config.js               # ✅ Config build + live-reload
└── README.md                    # À FAIRE
```

### Principe clé

- **`src/`** = ce qu'on code et versionne dans git
- **`public/`** = l'installation WordPress (gitignorée), le thème compilé y vit
- **Racine** = fichiers de config dev (package.json, vite.config.js, etc.) qui ne polluent PAS le thème

---

## Stack technique

| Outil         | Rôle                                                             | Statut |
| ------------- | ---------------------------------------------------------------- | ------ |
| **Vite 6**    | Build JS/SCSS, HMR, dev server                                  | ✅     |
| **SCSS**      | Préprocesseur CSS (compatible Timber/BEM, zero-config avec Vite) | ✅     |
| **Timber v2.3.3** | Templating Twig pour WordPress (via Composer)               | ✅     |
| **ACF**       | Custom fields, JSON sync versionné dans git                      | ✅ config prête, plugin à installer dans WP |
| **WP-CLI**    | Utilisé par le setup script pour configurer WP                   | ✅     |
| **Docker**    | Option d'env local (alternative à DevKinsta)                     | ✅     |

### Pourquoi SCSS plutôt que Tailwind ?

- Les templates Twig de Timber fonctionnent mieux avec des classes sémantiques (BEM)
- Tailwind surcharge les templates Twig avec des classes utilitaires
- SCSS est zero-config avec Vite (juste `sass` en devDependency)
- On peut toujours ajouter Tailwind plus tard si un projet le nécessite

### Base du thème

- ~~L'utilisateur télécharge le **timber/starter-theme** officiel~~ ✅ Fait et supprimé (`_tmp_timber/`)
- ~~On le réorganise dans `src/`~~ ✅ PHP dans `src/theme/`, Twig dans `src/templates/`
- ~~On y ajoute la couche Vite (inc/vite.php) et le cleanup~~ ✅
- Nom par défaut : `starter-theme` (renommable via le CLI)

---

## Build system (Vite)

### Mode développement (`npm run dev`) ✅

> **CHANGEMENT Phase 7 :** `npm run dev` lance désormais `bin/dev.js` au lieu de `sync.js --watch & vite`.
> `dev.js` orchestre les deux processus enfants, affiche un banner clair avec les URLs,
> et tue proprement les deux processus sur Ctrl+C (plus de sync.js orphelin).

1. `bin/dev.js` vérifie que `.env` existe (sinon erreur "Run npm run setup first")
2. Si projet Docker : vérifie si les containers tournent, les démarre automatiquement si besoin
3. Lance `sync.js --watch` + `vite` comme child processes
4. `sync.js` copie `src/theme/`, `src/templates/`, `src/acf-json/` → `THEME_DIR` puis surveille les changements
5. Vite dev server démarre sur `localhost:5173` (ou port suivant si occupé, `strictPort: false`)
6. `dev.js` détecte le port réel de Vite depuis stdout et réécrit `dist/hot` avec la bonne URL
7. `dev.js` affiche un banner avec :
   - WordPress : `http://localhost:{WP_PORT}` (le bon lien à ouvrir)
   - Vite HMR : `http://localhost:{VITE_PORT}` (port réel, peut être 5174+ si 5173 occupé)
   - phpMyAdmin : `http://localhost:{PMA_PORT}`
   - Note jaune si port Vite != 5173
   - Instructions : "Ctrl+C pour arrêter. Docker continue en arrière-plan."
8. `vite-plugin-live-reload` détecte les changements dans `THEME_DIR` → full reload navigateur
9. Pour SCSS/JS, Vite fait du vrai HMR (injection CSS sans reload)
10. Sur Ctrl+C ou fermeture VS Code : `dev.js` tue sync + vite proprement, supprime `dist/hot` (pas d'orphelins)
11. `npm run stop` arrête les containers Docker du projet

### Mode production (`npm run build`) ✅

1. `sync.js --production` copie PHP/Twig/ACF dans `THEME_DIR` + copie `vendor/`
2. Vite compile SCSS → CSS et bundle JS avec hashes dans `THEME_DIR/dist/`
3. Génère un `manifest.json` pour les assets hashés

### Le pont PHP ↔ Vite (`src/theme/inc/vite.php`) ✅

> **CHANGEMENT vs plan initial :** Le plan prévoyait la détection du dev server via une variable
> d'environnement ou un check HTTP. En pratique, on utilise un fichier `dist/hot` créé par
> `sync.js` qui contient l'URL du dev server. Plus fiable, pas de requête HTTP à chaque page load.

> **CHANGEMENT Phase 3 :** Le plan prévoyait `wp_enqueue_script_tag_attributes()` pour ajouter
> `type="module"` aux scripts. Cette fonction n'existe pas dans WordPress. Remplacé par le filtre
> `script_loader_tag` qui modifie le tag HTML directement. L'injection du client HMR (`@vite/client`)
> a aussi été déplacée dans un `add_action('wp_head', ..., 1)` séparé au lieu d'être dans le callback
> `wp_enqueue_scripts` (qui s'exécute trop tard pour injecter dans `wp_head`).

> **CHANGEMENT Phase 3 :** Le `base` de Vite est maintenant conditionnel : `/` en dev (pour que
> `@vite/client` et les entry points soient accessibles à des URLs simples) et
> `/wp-content/themes/{theme}/dist/` en prod (pour les URLs correctes dans le manifest).

- **En dev :** détecte `dist/hot`, injecte le client HMR tôt dans `<head>`, enqueue l'entry point avec `type="module"` via filtre `script_loader_tag`
- **En prod :** lit `dist/.vite/manifest.json` et enqueue les fichiers hashés (CSS + JS)

---

## CLI Setup (`bin/setup.sh`) — ✅ TERMINÉ

Script interactif en 4 étapes, résilient (reprend après échec) :

> **CHANGEMENT Phase 4b :** Ajout de pre-flight checks (node, npm, Docker), state file `.setup-state`
> pour reprendre après un échec sans retaper les réponses, opérations idempotentes (.env, Docker),
> remplacement dynamique du text domain dans tous les fichiers PHP/Twig, configuration du titre WP
> via WP-CLI, et question "Lancer dev ?" à la fin.

1. **Nom du projet** : demande un slug (sanitisé automatiquement : lowercase, tirets) → utilisé comme nom de thème, text domain, et `COMPOSE_PROJECT_NAME`
2. **Environnement** : choix entre Docker / DevKinsta / WP existant
   - Docker : vérifie que Docker daemon tourne, demande credentials DB, configure `VENDOR_PATH=/var/www/vendor`, `WP_PORT`, `PMA_PORT`
   - DevKinsta : demande le chemin du site → configure `THEME_DIR` avec chemin absolu, `VENDOR_PATH` vide
   - WP existant : demande le chemin WP → configure `THEME_DIR`, `VENDOR_PATH` vide
3. **Features** : "Utilises-tu ACF ?" → si non, supprime `inc/acf.php`, `src/acf-json/`, retire le require dans `functions.php`
4. **Configuration & Setup** :
   - Génère `.env` (avec confirmation si existe déjà) incluant `COMPOSE_PROJECT_NAME`, `WP_PORT`, `PMA_PORT`
   - Met à jour `Theme Name` et `Text Domain` dans `style.css`
   - Remplace le text domain `'starter-theme'` par le slug du projet dans tous les PHP/Twig
   - `composer install` + `npm install`
   - Docker : démarre les containers (scopés par projet), attend que WP réponde
   - `node bin/sync.js` (sync initial)
   - WP-CLI (installé automatiquement dans le container Docker si absent) :
     - Configure le titre du site (`blogname`)
     - Active le thème
     - Supprime Hello Dolly, Akismet
     - Supprime twentytwentythree/four/five
     - Supprime sample post, page, commentaire
     - Permalinks `/%postname%/`
     - Timezone `Europe/Paris`
   - Fallback : instructions manuelles si WP-CLI non disponible
   - **Propose de lancer `npm run dev`** directement

**Résilience :**
- Pre-flight checks : vérifie node, npm (fatal), composer (warning), Docker (si choisi)
- State file `.setup-state` : sauvegarde les réponses après les questions. Si le script échoue, on relance et il propose de reprendre avec les réponses sauvées
- Supprimé automatiquement en cas de succès

---

## ACF JSON Sync ✅

- Les fichiers JSON vivent dans `src/acf-json/` (versionné dans git)
- Un **symlink** est créé : `THEME_DIR/acf-json → src/acf-json`
- Quand on modifie les field groups dans wp-admin, ACF écrit à travers le symlink directement dans `src/acf-json/`
- On commit les changements JSON normalement

---

## Compatibilité DevKinsta ✅ (config prête, non testé)

DevKinsta stocke les sites dans `~/DevKinsta/public/{site-name}/`. Le boilerplate s'y connecte simplement via la variable `THEME_DIR` dans `.env` :

```
THEME_DIR=/Users/basile/DevKinsta/public/mon-site/wp-content/themes/mon-theme
```

Le build system copie dans ce dossier, DevKinsta sert le site. Aucune modification de DevKinsta nécessaire.

---

## Docker (alternative à DevKinsta) ✅

`docker/docker-compose.yml` avec :

- WordPress (Apache) sur `localhost:${WP_PORT}` (défaut 8080)
- MySQL 8.0 avec healthcheck
- phpMyAdmin sur `localhost:${PMA_PORT}` (défaut 8081)
- Volume : `../public` monté comme document root
- Volume : `../vendor` monté sur `/var/www/vendor`
- Variables d'env depuis `.env` via `--env-file`
- **Scopé par projet** via `COMPOSE_PROJECT_NAME` → pas de conflit entre projets

> **CHANGEMENT Phase 3 :** Ajout du volume `../vendor:/var/www/vendor` pour que le container
> WordPress puisse accéder à l'autoload Composer.

> **CHANGEMENT Phase 7 :** Ports rendus dynamiques (`WP_PORT`, `PMA_PORT`). `COMPOSE_PROJECT_NAME`
> ajouté pour scoper containers, volumes et réseaux par projet. Deux projets différents peuvent
> tourner en parallèle sur des ports différents sans conflit.

---

## .gitignore ✅

```
public/
node_modules/
vendor/
.env
.env.local
.setup-state
database/*.sql
dist/
_tmp_timber/
.DS_Store
Thumbs.db
.idea/
.vscode/
*.code-workspace
*.log
npm-debug.log*
```

**Uniquement le code source est versionné.** Après un `git clone` : `composer install` + `npm install` + `npm run setup`.

---

## Séquence d'implémentation

### Phase 1 : Fondations (config) ✅ TERMINÉE

- [x] `package.json` (Vite 6, sass, chokidar, dotenv, vite-plugin-live-reload)
- [x] `composer.json` (Timber v2.3.3)
- [x] `vite.config.js` (entry points, output, live-reload)
- [x] `.env.example` + `.env`
- [x] `.gitignore`

### Phase 2 : Thème source (`src/`) ✅ TERMINÉE

- [x] `src/theme/` — PHP du starter-theme Timber réorganisé
- [x] `src/theme/functions.php` — modifié pour autoload-path.php + inc/
- [x] `src/theme/src/StarterSite.php` — modifié, retiré enqueue_styles (géré par Vite)
- [x] `src/theme/inc/vite.php` — helper enqueue Vite dev/prod (fichier hot + manifest)
- [x] `src/theme/inc/timber.php` — config chemins Twig
- [x] `src/theme/inc/acf.php` — paths JSON ACF
- [x] `src/theme/inc/cleanup.php` — nettoyage wp_head, emojis, generator, etc.
- [x] `src/templates/` — tous les templates Twig du starter-theme (layouts/, templates/, partials/)
- [x] `src/scss/` — scaffold SCSS (main.scss, _variables.scss, base/_reset.scss, base/_typography.scss)
- [x] `src/js/main.js` — entry point qui importe le SCSS

### Phase 3 : Build system ✅ TERMINÉE

- [x] `bin/sync.js` — copie src/ → THEME_DIR, génère autoload-path.php, crée symlink acf-json, fichier hot
- [x] Watch mode via `sync.js --watch` + `vite-plugin-live-reload` (pas de plugin Vite custom, plus simple)
- [x] Build prod testé : CSS/JS compilés avec hashes, manifest.json généré
- [x] HMR CSS testé ✅ — modification SCSS → injection CSS sans reload
- [x] Live reload Twig testé ✅ — modification .twig → full reload navigateur

**Bugs corrigés en Phase 3 :**
- [x] `autoload-path.php` pointait vers chemin macOS local, inaccessible dans Docker → ajout volume `vendor/` + variable `VENDOR_PATH`
- [x] `functions.php` : `StarterSite` pas trouvée (autoload PSR-4 Composer = chemins locaux) → ajout `require_once` explicite
- [x] `vite.php` : `wp_enqueue_script_tag_attributes()` n'existe pas dans WP → remplacé par filtre `script_loader_tag`
- [x] `vite.php` : client HMR `@vite/client` pas injecté (add_action wp_head dans wp_enqueue_scripts = trop tard) → déplacé dans hook wp_head séparé
- [x] `vite.config.js` : `base` fixe en dev causait 404 sur `@vite/client` → base conditionnel (`/` en dev, chemin complet en prod)

### Phase 4 : CLI Setup ✅ TERMINÉE

- [x] `bin/setup.sh` — script interactif (nom du projet, slug auto-sanitisé)
- [x] Support DevKinsta / Docker / WP existant (3 modes avec config adaptée)
- [x] Questions fonctionnelles (ACF oui/non → supprime acf.php, acf-json/, require dans functions.php)
- [x] Génération `.env` dynamique selon l'environnement choisi
- [x] Mise à jour automatique du Theme Name dans style.css
- [x] Installation dépendances (composer install + npm install)
- [x] Démarrage Docker containers si mode Docker
- [x] Sync initial via `node bin/sync.js`
- [x] Nettoyage WP via WP-CLI (supprime Hello Dolly, Akismet, thèmes par défaut, sample content, permalinks /%postname%/)
- [x] WP-CLI : installation auto dans le container Docker si absent
- [x] Activation du thème via WP-CLI
- [x] Fallback gracieux si WP-CLI/Docker/Composer/npm non disponibles

### Phase 4b : Setup résilient + nettoyage contenu ✅ TERMINÉE

**Setup résilient :**
- [x] Pre-flight checks (node, npm, composer, Docker daemon)
- [x] State file `.setup-state` pour reprendre après échec sans retaper les réponses
- [x] Opérations idempotentes (.env, Docker containers)
- [x] Configuration titre WP via WP-CLI (`blogname`)
- [x] Proposition "Lancer dev ?" à la fin du setup

**Nettoyage contenu hardcodé :**
- [x] Supprimé démo Timber dans `StarterSite.php` (foo/bar/stuff/notes/myfoo)
- [x] Supprimé `'foo' => 'bar'` dans `index.php`
- [x] Supprimé `{{ foo }}` dans `index.twig`
- [x] Footer : `Copyright 2026` → `{{ site.name }} © {{ 'now'|date('Y') }}`
- [x] Internationalisé les titres dans `archive.php`, `search.php`, `author.php`

**i18n (translation-ready par défaut) :**
- [x] `src/theme/inc/i18n.php` — `load_theme_textdomain()`
- [x] `src/theme/languages/.gitkeep` — dossier traductions
- [x] `Text Domain: starter-theme` + `Domain Path: /languages` dans `style.css`
- [x] `require_once inc/i18n.php` dans `functions.php`
- [x] Toutes les chaînes UI wrappées avec `{{ __('...', 'starter-theme') }}` dans 10 templates Twig
- [x] Text domain fixé à `'starter-theme'` (remplacé dynamiquement par le slug du projet via `setup.sh`)
- [x] Le thème est toujours translation-ready — pas de question dans le setup, c'est un standard

### Phase 5 : Docker ✅ TERMINÉE

- [x] `docker/docker-compose.yml` (WordPress + MySQL 8 + phpMyAdmin)
- [x] Test : containers lancés, WordPress installé sur localhost:8080

### Phase 6 : Documentation ⏳ À FAIRE

- [ ] `README.md` avec instructions complètes

### Phase 7 : DX — Expérience développeur ✅ TERMINÉE

- [x] `bin/dev.js` — orchestrateur qui lance sync + vite comme child processes
- [x] Banner clair au démarrage avec les URLs (WordPress, Vite HMR, phpMyAdmin)
- [x] Cleanup propre sur Ctrl+C / fermeture VS Code (plus de sync.js orphelin)
- [x] `npm run stop` — arrête les containers Docker du projet
- [x] Ports Docker dynamiques (`WP_PORT`, `PMA_PORT`) dans `.env`
- [x] `COMPOSE_PROJECT_NAME` pour scoper containers/volumes/réseaux par projet
- [x] Deux projets peuvent tourner en parallèle sur des ports différents

### Phase 7b : DX — Port Vite dynamique + Docker auto-start ✅ TERMINÉE

- [x] `vite.config.js` : `strictPort: false` + suppression `origin` hardcodé — Vite cherche un port libre si 5173 occupé
- [x] `dev.js` : détecte le port réel de Vite depuis stdout (regex sur "Local: http://localhost:XXXX")
- [x] `dev.js` : réécrit `dist/hot` avec le port réel → `vite.php` lit la bonne URL automatiquement
- [x] `dev.js` : supprime `dist/hot` au cleanup (Ctrl+C) → PHP retombe en mode prod
- [x] `dev.js` : banner affiche le port Vite réel + message jaune si port fallback
- [x] `dev.js` : vérifie que `.env` existe → sinon erreur "Run npm run setup first"
- [x] `dev.js` : si projet Docker, vérifie si containers tournent → les démarre automatiquement si down
- [x] `dev.js` : attend que WordPress soit ready avant de lancer sync + Vite

---

## Vérification / Test

1. ✅ **Docker :** containers lancés, WordPress installé et accessible sur `localhost:8080`
2. ✅ **Sync :** `node bin/sync.js` copie tous les fichiers correctement
3. ✅ **Build prod :** `vite build` produit les assets hashés + `manifest.json`
4. ✅ **HMR :** thème activé dans WP → `npm run dev` → HMR SCSS (injection sans reload) + live reload Twig (full reload) fonctionnels
5. ✅ **Setup complet :** `npm run setup` → questions → .env → Docker → sync → WP-CLI → tout fonctionne
6. ✅ **Setup resume :** interruption → relance → reprend avec les réponses sauvées
7. ✅ **Setup pre-flight :** Docker non lancé → erreur claire avant les questions
8. ✅ **Nettoyage contenu :** plus de foo/bar, footer avec site.name, titre WP = PROJECT_NAME
9. ✅ **i18n :** toutes les chaînes wrappées avec `__()`, text domain remplacé par le slug du projet
10. ✅ **Banner dev :** `npm run dev` → affiche les bons URLs (WordPress `:8080`, pas Vite `:5173`)
11. ✅ **Cleanup dev :** Ctrl+C → sync + vite tués proprement, aucun orphelin, `dist/hot` supprimé
12. ✅ **npm run stop :** arrête les containers Docker
13. ✅ **Docker scoping :** containers/volumes préfixés par le nom du projet, pas de conflit multi-projets
14. ✅ **Port Vite fallback :** port 5173 occupé → Vite prend 5174, banner affiche le bon port, `dist/hot` mis à jour
15. ✅ **Docker auto-start :** `npm run dev` avec Docker down → démarre automatiquement les containers, attend WP
16. ✅ **Pas de .env :** `npm run dev` sans `.env` → erreur claire "Run npm run setup first"
17. ⏳ **ACF :** installer ACF → créer un field group → vérifier que le JSON arrive dans `src/acf-json/`
18. ⏳ **DevKinsta :** tester en changeant `THEME_DIR` dans `.env`

---

## Points d'attention

- **Autoload Composer :** ✅ Résolu via `autoload-path.php` généré par `sync.js`. En dev Docker, pointe vers `/var/www/vendor/autoload.php` (via `VENDOR_PATH` dans `.env`). En dev local/DevKinsta, pointe vers le chemin absolu du repo. En prod, `vendor/` est copié dans le thème.
- **StarterSite autoload :** ✅ L'autoload PSR-4 de Composer contient des chemins absolus locaux qui ne fonctionnent pas dans Docker. Résolu par un `require_once` explicite dans `functions.php` plutôt que de dépendre de l'autoloader pour les classes du thème.
- **HTTPS DevKinsta :** Si DevKinsta sert en HTTPS, Vite doit aussi être en HTTPS (configurable dans `vite.config.js`).
- **Déploiement :** `npm run build` produit un thème autonome. Pour la prod, `vendor/` (Timber) est inclus automatiquement par `sync.js --production`.

---

## Changements par rapport au plan initial

1. **Structure templates Twig** : gardé la hiérarchie Timber (`layouts/`, `templates/`, `partials/`) au lieu de tout mettre à plat dans `src/templates/`
2. **Watch/sync** : `sync.js --watch` lancé en parallèle de Vite via `&` dans npm script, au lieu d'un plugin Vite custom — plus simple et découplé
3. **Détection dev server** : fichier `dist/hot` au lieu d'un check HTTP ou variable d'env — plus fiable
4. **Manifest path** : Vite 6 génère le manifest dans `dist/.vite/manifest.json` (pas `dist/manifest.json`), `vite.php` adapté en conséquence
5. **CLI setup** : ajout prévu de questions fonctionnelles ("utilises-tu ACF ?", etc.) pour retirer/ajouter des fichiers du boilerplate
6. **Docker vendor volume** : ajout de `../vendor:/var/www/vendor` dans docker-compose + `VENDOR_PATH` dans `.env` pour résoudre l'autoload cross-environnement
7. **Vite base conditionnel** : `base: '/'` en dev, `base: '/wp-content/themes/{theme}/dist/'` en prod — le plan initial avait un base fixe qui cassait `@vite/client` en dev
8. **StarterSite require** : `require_once` explicite au lieu de dépendre de l'autoload PSR-4 Composer (chemins absolus incompatibles Docker)
9. **vite.php réécrit** : client HMR injecté via `wp_head` priorité 1, `type="module"` via filtre `script_loader_tag`, suppression de `wp_enqueue_script_tag_attributes()` inexistante
10. **Setup résilient** : pre-flight checks, state file `.setup-state` pour reprendre après échec, opérations idempotentes
11. **Nettoyage contenu** : supprimé toutes les démos Timber (foo/bar/stuff/notes/myfoo), footer dynamique, titre WP configuré via WP-CLI
12. **i18n** : thème toujours translation-ready (text domain `starter-theme`, `load_theme_textdomain()`, toutes les chaînes UI wrappées avec `__()`)
13. **Text domain dynamique** : `setup.sh` remplace `'starter-theme'` par le slug du projet dans tous les PHP/Twig via `sed`
14. **Orchestrateur dev** : `bin/dev.js` remplace `sync.js --watch & vite` — banner clair, cleanup propre, plus d'orphelins
15. **Docker scopé** : `COMPOSE_PROJECT_NAME`, ports dynamiques (`WP_PORT`, `PMA_PORT`) — multi-projets sans conflit
16. **npm run stop** : commande dédiée pour arrêter les containers Docker du projet
17. **Port Vite dynamique** : `strictPort: false` dans vite.config.js, `dev.js` détecte le port réel depuis stdout de Vite et réécrit `dist/hot` — plus de crash si le port 5173 est occupé
18. **Docker auto-start** : `dev.js` vérifie `.env`, démarre les containers Docker automatiquement si down, attend que WordPress soit ready
19. **Cleanup dist/hot** : `dev.js` supprime `dist/hot` au Ctrl+C pour que PHP retombe en mode production
