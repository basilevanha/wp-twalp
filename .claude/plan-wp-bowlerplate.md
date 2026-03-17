# Plan : WordPress Boilerplate Moderne (Timber + Vite + ACF)

## Contexte

**Problème :** Quand on développe un thème WordPress avec Timber, les fichiers de configuration dev (package.json, .gitignore, node_modules, etc.) se retrouvent dans le dossier du thème (`wp-content/themes/mon-theme/`). Cela pollue le thème et le repo git avec des fichiers qui n'ont rien à voir avec WordPress.

**Objectif :** Créer un boilerplate où le **code source** (templates Twig, SCSS, JS, config) vit à la racine du projet git, et un **système de build** compile/copie le thème dans l'installation WordPress. Le repo git ne contient que le code source, jamais l'installation WP.

**Résultat attendu :** Un développeur clone le repo, lance `npm run setup`, puis `npm run dev`, et il a un WordPress local fonctionnel avec HMR.

---

## Structure des dossiers

```
wp-boilerplate/
├── bin/
│   ├── setup.sh                 # CLI interactif de configuration
│   └── sync.js                  # Script de copie src/ → thème WP
├── database/                    # Dumps SQL optionnels
│   └── .gitkeep
├── docker/
│   └── docker-compose.yml       # WordPress + MySQL + phpMyAdmin
├── src/                         # === ESPACE DE TRAVAIL DU DEV ===
│   ├── acf-json/                # ACF field groups (versionné dans git)
│   ├── fonts/                   # Polices custom
│   ├── images/                  # Images du thème
│   ├── js/
│   │   └── main.js              # Point d'entrée JS
│   ├── scss/
│   │   ├── main.scss            # Point d'entrée SCSS
│   │   ├── _variables.scss
│   │   ├── base/
│   │   ├── components/
│   │   └── layouts/
│   ├── templates/               # Templates Twig (Timber)
│   │   ├── base.twig
│   │   ├── index.twig
│   │   ├── single.twig
│   │   ├── page.twig
│   │   └── partials/
│   └── theme/                   # Fichiers PHP du thème
│       ├── functions.php
│       ├── index.php
│       ├── style.css            # Header WP uniquement (metadata)
│       ├── single.php
│       ├── page.php
│       └── inc/
│           ├── vite.php         # Helper d'enqueue des assets Vite
│           ├── timber.php       # Configuration Timber
│           ├── acf.php          # Paths ACF JSON
│           └── cleanup.php      # Nettoyage wp_head, emojis, etc.
├── public/                      # Installation WP (GITIGNORE)
│   └── wp-content/themes/{nom}/ # ← BUILD OUTPUT (cible de compilation)
├── .env.example
├── .gitignore
├── composer.json                # Timber v2
├── package.json                 # Vite + plugins
├── vite.config.js               # Config build + sync plugin
└── README.md
```

### Principe clé

- **`src/`** = ce qu'on code et versionne dans git
- **`public/`** = l'installation WordPress (gitignorée), le thème compilé y vit
- **Racine** = fichiers de config dev (package.json, vite.config.js, etc.) qui ne polluent PAS le thème

---

## Stack technique

| Outil         | Rôle                                                             |
| ------------- | ---------------------------------------------------------------- |
| **Vite**      | Build JS/SCSS, HMR, dev server                                   |
| **SCSS**      | Préprocesseur CSS (compatible Timber/BEM, zero-config avec Vite) |
| **Timber v2** | Templating Twig pour WordPress (via Composer)                    |
| **ACF**       | Custom fields, JSON sync versionné dans git                      |
| **WP-CLI**    | Utilisé par le setup script pour configurer WP                   |
| **Docker**    | Option d'env local (alternative à DevKinsta)                     |

### Pourquoi SCSS plutôt que Tailwind ?

- Les templates Twig de Timber fonctionnent mieux avec des classes sémantiques (BEM)
- Tailwind surcharge les templates Twig avec des classes utilitaires
- SCSS est zero-config avec Vite (juste `sass` en devDependency)
- On peut toujours ajouter Tailwind plus tard si un projet le nécessite

### Base du thème

- L'utilisateur télécharge le **timber/starter-theme** officiel
- On le réorganise dans `src/` (PHP dans `src/theme/`, Twig dans `src/templates/`, etc.)
- On y ajoute la couche Vite (inc/vite.php) et le cleanup
- Nom par défaut : `starter-theme` (renommable via le CLI)

---

## Build system (Vite)

### Mode développement (`npm run dev`)

1. `sync.js` copie `src/theme/`, `src/templates/`, `src/acf-json/` → `THEME_DIR`
2. Vite dev server démarre sur `localhost:5173`
3. Un plugin Vite custom (`vite-plugin-sync`) watch `src/` et re-copie les fichiers PHP/Twig à chaque sauvegarde
4. `vite-plugin-live-reload` détecte les changements dans `THEME_DIR` → full reload navigateur
5. Pour SCSS/JS, Vite fait du vrai HMR (injection CSS sans reload)

### Mode production (`npm run build`)

1. `sync.js` copie PHP/Twig/ACF dans `THEME_DIR`
2. Vite compile SCSS → CSS et bundle JS avec hashes dans `THEME_DIR/dist/`
3. Génère un `manifest.json` pour les assets hashés
4. Copie `vendor/` (Timber) dans le thème pour le déploiement

### Le pont PHP ↔ Vite (`src/theme/inc/vite.php`)

- **En dev :** enqueue `http://localhost:5173/@vite/client` + entry point via module
- **En prod :** lit `dist/manifest.json` et enqueue les fichiers hashés

---

## CLI Setup (`bin/setup.sh`)

Script interactif qui :

1. **Demande** : nom du projet, type d'environnement (DevKinsta / Docker / WP existant)
2. **Si DevKinsta** : demande le chemin du site → configure `THEME_DIR` dans `.env`
3. **Si Docker** : demande les credentials DB → lance `docker-compose up`
4. **Si WP existant** : demande le chemin → configure `THEME_DIR`
5. **Nettoyage WP** (via WP-CLI) :
    - Supprime Hello Dolly, Akismet
    - Supprime les thèmes par défaut inutiles
    - Supprime le contenu sample (post, page, commentaire)
    - Configure les permalinks en `/%postname%/`
6. **Installe** ACF et Timber via WP-CLI (ou invite à le faire manuellement)
7. **Lance** `composer install` (Timber v2)
8. **Sync** initial + crée le symlink `acf-json`
9. **Active** le thème

---

## ACF JSON Sync

- Les fichiers JSON vivent dans `src/acf-json/` (versionné dans git)
- Un **symlink** est créé : `THEME_DIR/acf-json → src/acf-json`
- Quand on modifie les field groups dans wp-admin, ACF écrit à travers le symlink directement dans `src/acf-json/`
- On commit les changements JSON normalement

---

## Compatibilité DevKinsta

DevKinsta stocke les sites dans `~/DevKinsta/public/{site-name}/`. Le boilerplate s'y connecte simplement via la variable `THEME_DIR` dans `.env` :

```
THEME_DIR=/Users/basile/DevKinsta/public/mon-site/wp-content/themes/mon-theme
```

Le build system copie dans ce dossier, DevKinsta sert le site. Aucune modification de DevKinsta nécessaire.

---

## Docker (alternative à DevKinsta)

`docker/docker-compose.yml` avec :

- WordPress (Apache) sur `localhost:8080`
- MySQL 8.0
- phpMyAdmin sur `localhost:8081`
- Volume : `./public` monté comme document root

---

## .gitignore

```
public/
node_modules/
vendor/
.env
database/*.sql
dist/
.DS_Store
```

**Uniquement le code source est versionné.** Après un `git clone` : `composer install` + `npm install` + `npm run setup`.

---

## Séquence d'implémentation

### Phase 1 : Fondations (config)

- [ ] `package.json` (Vite, sass, vite-plugin-live-reload)
- [ ] `composer.json` (Timber v2)
- [ ] `vite.config.js` (entry points, output, sync plugin, live-reload)
- [ ] `.env.example`
- [ ] `.gitignore`

### Phase 2 : Thème source (`src/`)

- [ ] `src/theme/` — PHP skeleton (functions.php, style.css, index.php, inc/\*.php)
- [ ] `src/theme/inc/vite.php` — helper enqueue Vite dev/prod
- [ ] `src/theme/inc/timber.php` — config Timber
- [ ] `src/theme/inc/acf.php` — paths JSON ACF
- [ ] `src/templates/` — templates Twig de base
- [ ] `src/scss/` — scaffold SCSS
- [ ] `src/js/main.js` — entry point

### Phase 3 : Build system

- [ ] `bin/sync.js` — copie src/ → THEME_DIR
- [ ] Plugin Vite custom pour watch/sync PHP et Twig
- [ ] Tester HMR CSS + live reload PHP/Twig

### Phase 4 : CLI Setup

- [ ] `bin/setup.sh` — script interactif
- [ ] Support DevKinsta / Docker / WP existant
- [ ] Nettoyage WP via WP-CLI
- [ ] Création symlink ACF

### Phase 5 : Docker

- [ ] `docker/docker-compose.yml`
- [ ] Test du flow complet Docker

### Phase 6 : Documentation

- [ ] `README.md` avec instructions complètes

---

## Vérification / Test

1. **Docker :** `git clone` → `npm install` → `composer install` → `npm run setup` (Docker) → `npm run dev` → ouvrir `localhost:8080` → modifier un fichier SCSS → vérifier HMR → modifier un fichier Twig → vérifier live reload
2. **DevKinsta :** Créer un site DevKinsta → `npm run setup` (DevKinsta) → `npm run dev` → vérifier que le thème est actif et que le HMR fonctionne
3. **Build prod :** `npm run build` → vérifier que `THEME_DIR/dist/` contient les assets hashés et le `manifest.json`
4. **ACF :** Créer un field group dans wp-admin → vérifier que le JSON apparaît dans `src/acf-json/` → commiter → vérifier que ça se charge sur un autre environnement

---

## Points d'attention

- **Autoload Composer :** Le thème (dans `public/`) doit charger `vendor/autoload.php` qui est à la racine du repo. Le sync script génère un fichier `autoload-path.php` avec le chemin absolu.
- **HTTPS DevKinsta :** Si DevKinsta sert en HTTPS, Vite doit aussi être en HTTPS (configurable dans `vite.config.js`).
- **Déploiement :** `npm run build` produit un thème autonome. Pour la prod, `vendor/` (Timber) doit être inclus dans le thème. Le build script s'en charge.
