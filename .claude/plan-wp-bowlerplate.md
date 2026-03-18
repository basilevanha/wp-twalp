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
│   └── sync.js                  # Script de copie src/ → thème WP ✅
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
│       │   └── StarterSite.php  # ✅ (modifié : retiré enqueue_styles, géré par Vite)
│       └── inc/
│           ├── vite.php         # ✅ Helper d'enqueue des assets Vite
│           ├── timber.php       # ✅ Configuration Timber
│           ├── acf.php          # ✅ Paths JSON ACF
│           └── cleanup.php      # ✅ Nettoyage wp_head, emojis, etc.
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
| **WP-CLI**    | Utilisé par le setup script pour configurer WP                   | À FAIRE (Phase 4) |
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

> **CHANGEMENT vs plan initial :** Le plan prévoyait un "plugin Vite custom" (`vite-plugin-sync`)
> intégré dans `vite.config.js`. En pratique, le watch est géré par `bin/sync.js --watch`
> lancé en parallèle de Vite via `&` dans le script npm. Plus simple, même résultat.

1. `sync.js --watch` copie `src/theme/`, `src/templates/`, `src/acf-json/` → `THEME_DIR` puis surveille les changements
2. Vite dev server démarre sur `localhost:5173`
3. `vite-plugin-live-reload` détecte les changements dans `THEME_DIR` → full reload navigateur
4. Pour SCSS/JS, Vite fait du vrai HMR (injection CSS sans reload)

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

Script interactif en 5 étapes :

1. **Nom du projet** : demande un slug (sanitisé automatiquement : lowercase, tirets)
2. **Environnement** : choix entre Docker / DevKinsta / WP existant
   - Docker : demande credentials DB, configure `VENDOR_PATH=/var/www/vendor`, lance `docker compose up -d`
   - DevKinsta : demande le chemin du site → configure `THEME_DIR` avec chemin absolu, `VENDOR_PATH` vide
   - WP existant : demande le chemin WP → configure `THEME_DIR`, `VENDOR_PATH` vide
3. **Features** : "Utilises-tu ACF ?" → si non, supprime `inc/acf.php`, `src/acf-json/`, retire le require dans `functions.php`
4. **Configuration** : génère `.env`, met à jour `Theme Name` dans `style.css`
5. **Setup** :
   - `composer install` + `npm install`
   - Docker : démarre les containers, attend que WP réponde
   - `node bin/sync.js` (sync initial)
   - WP-CLI (installé automatiquement dans le container Docker si absent) :
     - Active le thème
     - Supprime Hello Dolly, Akismet
     - Supprime twentytwentythree/four/five
     - Supprime sample post, page, commentaire
     - Permalinks `/%postname%/`
     - Timezone `Europe/Paris`
   - Fallback : instructions manuelles si WP-CLI non disponible

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

- WordPress (Apache) sur `localhost:8080`
- MySQL 8.0 avec healthcheck
- phpMyAdmin sur `localhost:8081`
- Volume : `../public` monté comme document root
- Volume : `../vendor` monté sur `/var/www/vendor` (ajouté Phase 3, voir ci-dessous)
- Variables d'env depuis `.env` avec valeurs par défaut

> **CHANGEMENT Phase 3 :** Ajout du volume `../vendor:/var/www/vendor` pour que le container
> WordPress puisse accéder à l'autoload Composer. Le `sync.js` génère `autoload-path.php` avec
> le chemin `/var/www/vendor/autoload.php` quand `VENDOR_PATH` est défini dans `.env`.
> Sans ce volume, le chemin local macOS (`/Users/...`) n'existait pas dans le container → fatal error.

---

## .gitignore ✅

```
public/
node_modules/
vendor/
.env
.env.local
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

### Phase 5 : Docker ✅ TERMINÉE

- [x] `docker/docker-compose.yml` (WordPress + MySQL 8 + phpMyAdmin)
- [x] Test : containers lancés, WordPress installé sur localhost:8080

### Phase 6 : Documentation ⏳ À FAIRE

- [ ] `README.md` avec instructions complètes

---

## Vérification / Test

1. ✅ **Docker :** containers lancés, WordPress installé et accessible sur `localhost:8080`
2. ✅ **Sync :** `node bin/sync.js` copie tous les fichiers correctement dans `public/wp-content/themes/starter-theme/`
3. ✅ **Build prod :** `vite build` produit les assets hashés + `manifest.json`
4. ✅ **HMR :** thème activé dans WP → `npm run dev` → HMR SCSS (injection sans reload) + live reload Twig (full reload) fonctionnels
5. ⏳ **ACF :** installer ACF → créer un field group → vérifier que le JSON arrive dans `src/acf-json/`
6. ⏳ **DevKinsta :** tester en changeant `THEME_DIR` dans `.env`

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
