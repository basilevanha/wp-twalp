# Plan : Amélioration setup.sh + nettoyage contenu hardcodé + i18n

## Contexte

Le `setup.sh` fonctionne mais n'est pas résilient aux erreurs (si Docker n'est pas lancé, il faut tout recommencer). Le thème contient du contenu de démo Timber (foo/bar, copyright sans nom de site) et des chaînes en dur non traduisibles. L'utilisateur veut aussi préparer le thème pour le multilangue.

**3 axes de travail :**

1. Rendre `setup.sh` résilient (pre-flight checks + state file pour reprendre)
2. Supprimer le contenu hardcodé / de démo, centraliser la config
3. Préparer l'i18n (text domain, `__()` dans les templates, question multilangue)

---

## Axe 1 — setup.sh résilient

**Fichier :** `bin/setup.sh`

### 1a. Pre-flight checks (avant les questions)

- Vérifier `node`, `npm` disponibles (erreur fatale si absents)
- Vérifier `composer` disponible (warning si absent)
- Le check Docker se fait **après** le choix d'environnement (dans le `case 1)`) : vérifier `docker info` → erreur si Docker daemon pas lancé

### 1b. State file `.setup-state` pour reprendre après échec

- Au démarrage : si `.setup-state` existe → proposer "Reprendre avec les réponses sauvegardées ? [O/n]"
- Si oui : `source .setup-state`, sauter les questions
- Après les questions : sauvegarder toutes les réponses dans `.setup-state`
- À la fin (succès) : supprimer `.setup-state`
- Sur erreur : garder `.setup-state` + afficher message "Re-run pour reprendre"
- Ajouter `.setup-state` au `.gitignore`

### 1c. Idempotence

- `.env` : demander confirmation si le fichier existe déjà
- Docker : vérifier si les containers tournent déjà avant de lancer `docker compose up`

---

## Axe 2 — Supprimer le contenu hardcodé

### 2a. StarterSite.php — supprimer le contenu de démo

- **Supprimer** `$context['foo']`, `$context['stuff']`, `$context['notes']` de `add_to_context()` (lignes 55-57)
- **Supprimer** la méthode `myfoo()` (lignes 133-137)
- **Supprimer** le filtre Twig `myfoo` dans `add_filters_to_twig()` (lignes 148-150) → retourner `$filters` directement
- **Changer** le text domain `'timber-starter'` → `'starter-theme'` (ligne 71) — sera remplacé par setup.sh

### 2b. index.php — supprimer `'foo' => 'bar'`

- Ligne 21-25 : `Timber::context(['foo' => 'bar'])` → `Timber::context()`

### 2c. index.twig — supprimer `{{ foo }}`

- Ligne 4 : supprimer `<h2>{{ foo }}</h2>`

### 2d. footer.twig — ajouter le nom du site

- `Copyright {{ 'now'|date('Y') }}` → `{{ site.name }} &copy; {{ 'now'|date('Y') }}`

### 2e. archive.php — internationaliser les chaînes

- `'Archive'` → `__('Archive', 'starter-theme')`
- `'Archive: '` → `__('Archive:', 'starter-theme') . ' '`
- `'Search results for '` dans search.php → `__('Search results for', 'starter-theme') . ' '`

### 2f. setup.sh — configurer le titre WP via WP-CLI

- Ajouter `$WP_CLI option update blogname "$PROJECT_NAME"` dans la section WP-CLI

### 2g. setup.sh — remplacer le text domain dans tous les fichiers

- `sed` sur `src/theme/**/*.php` et `src/templates/**/*.twig` : remplacer `'starter-theme'` par `'$PROJECT_NAME'`

---

## Axe 3 — Préparation i18n / multilangue

### 3a. Infrastructure i18n

- **Nouveau fichier** `src/theme/inc/i18n.php` : `load_theme_textdomain('starter-theme', get_template_directory() . '/languages')`
- **Ajouter** `require_once __DIR__ . '/inc/i18n.php'` dans `functions.php` (après cleanup.php)
- **Ajouter** `Text Domain: starter-theme` et `Domain Path: /languages` dans `style.css`
- **Créer** `src/theme/languages/.gitkeep`

### 3b. Internationaliser les templates Twig

Tous les strings UI wrappés avec `{{ __('string', 'starter-theme') }}` :

| Fichier              | Strings à wrapper                                                                                                               |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| base.twig:9          | `Skip to content` (ajouter text domain)                                                                                         |
| base.twig:32         | `Sorry, no content`                                                                                                             |
| single.twig:10       | `By`                                                                                                                            |
| single.twig:20       | `comments` (heading)                                                                                                            |
| single.twig:30       | `comments for this post are closed`                                                                                             |
| 404.twig:4           | `Sorry, we couldn't find what you're looking for.`                                                                              |
| comment-form.twig    | `Add comment`, `Email`, `Name`, `Website`, `Comment`, `Leave a comment...`, `Send`, `Cancel`, `Your comment will be revised...` |
| comment.twig         | `says`, `replies`                                                                                                               |
| pagination.twig      | `First`, `Previous`, `Next`, `Last` (×2 chacun)                                                                                 |
| tease-post.twig      | `Keep reading`                                                                                                                  |
| single-password.twig | `Password:`, `Password` (placeholder), `Submit`                                                                                 |

### 3c. Question multilangue dans setup.sh

- Ajouter "Ce site sera-t-il multilangue ? [y/N]" dans la section Features
- Si oui : afficher les instructions (installer WPML ou Polylang) dans le résumé final
- **Pas de changement structurel** — le multilangue est géré par le plugin (DB level), le thème est prêt grâce au text domain

---

## Ordre d'implémentation

1. **i18n infrastructure** (3a) — créer i18n.php, languages/, mettre à jour style.css et functions.php
2. **Nettoyage contenu** (2a-2e) + **internationalisation templates** (3b) — en un seul pass
3. **setup.sh** (1a-1c + 2f-2g + 3c) — toutes les améliorations du script

---

## Fichiers modifiés

| Fichier                                        | Action                                                                       |
| ---------------------------------------------- | ---------------------------------------------------------------------------- |
| `bin/setup.sh`                                 | Réécriture majeure (preflight, state, idempotence, text domain, multilangue) |
| `src/theme/src/StarterSite.php`                | Supprimer démo, fixer text domain                                            |
| `src/theme/index.php`                          | Supprimer `foo => bar`                                                       |
| `src/theme/functions.php`                      | Ajouter require i18n.php                                                     |
| `src/theme/style.css`                          | Ajouter Text Domain + Domain Path                                            |
| `src/theme/archive.php`                        | Internationaliser les titres                                                 |
| `src/theme/search.php`                         | Internationaliser le titre                                                   |
| `src/theme/author.php`                         | Vérifier text domain (déjà `timber-starter` → `starter-theme`)               |
| `src/theme/inc/i18n.php`                       | **Nouveau** — load_theme_textdomain                                          |
| `src/theme/languages/.gitkeep`                 | **Nouveau** — dossier traductions                                            |
| `src/templates/layouts/base.twig`              | Ajouter text domain au `_e()`, wrapper fallback                              |
| `src/templates/partials/footer.twig`           | Ajouter `site.name`                                                          |
| `src/templates/templates/index.twig`           | Supprimer `{{ foo }}`                                                        |
| `src/templates/templates/single.twig`          | Wrapper "By", "comments", "closed"                                           |
| `src/templates/templates/404.twig`             | Wrapper message erreur                                                       |
| `src/templates/templates/single-password.twig` | Wrapper labels                                                               |
| `src/templates/partials/comment-form.twig`     | Wrapper 9 strings                                                            |
| `src/templates/partials/comment.twig`          | Wrapper "says", "replies"                                                    |
| `src/templates/partials/pagination.twig`       | Wrapper 4×2 labels                                                           |
| `src/templates/partials/tease-post.twig`       | Wrapper "Keep reading"                                                       |
| `.gitignore`                                   | Ajouter `.setup-state`                                                       |

---

## Vérification

1. **Lancer `npm run setup`** en mode Docker → vérifier le flow complet (questions → .env → containers → sync → WP-CLI)
2. **Interrompre le setup** (Ctrl+C après les questions) → relancer → vérifier que "Reprendre ?" fonctionne
3. **Lancer sans Docker Desktop** → vérifier le message d'erreur clair avant les questions
4. **Ouvrir le site** → vérifier qu'il n'y a plus de "bar", que le footer affiche le nom du site, que le titre WP correspond au PROJECT_NAME
5. **Vérifier les templates** → aucune chaîne anglaise brute, tout wrappé dans `__()`
