# Plan : Nettoyage contenu hardcodé + i18n + setup.sh résilient

## Contexte

Le thème contient du contenu de démo Timber (foo/bar, copyright sans nom de site) et des chaînes en dur non traduisibles. Le `setup.sh` fonctionne mais n'est pas résilient aux erreurs (si Docker n'est pas lancé, il faut tout recommencer). On veut aussi que le thème soit toujours "translation-ready" pour le multilangue.

**3 axes de travail (dans cet ordre) :**

1. Supprimer le contenu hardcodé / de démo, centraliser la config
2. Préparer l'i18n (text domain, `__()` dans les templates) — toujours actif, pas de question dans le setup
3. Rendre `setup.sh` résilient (pre-flight checks + state file pour reprendre)

---

## Axe 1 — Supprimer le contenu hardcodé

### 1a. StarterSite.php — supprimer le contenu de démo

- **Supprimer** `$context['foo']`, `$context['stuff']`, `$context['notes']` de `add_to_context()` (lignes 55-57)
- **Supprimer** la méthode `myfoo()` (lignes 133-137)
- **Supprimer** le filtre Twig `myfoo` dans `add_filters_to_twig()` (lignes 148-150) → retourner `$filters` directement
- **Changer** le text domain `'timber-starter'` → `'starter-theme'` (ligne 71) — sera remplacé par setup.sh

### 1b. index.php — supprimer `'foo' => 'bar'`

- Ligne 21-25 : `Timber::context(['foo' => 'bar'])` → `Timber::context()`

### 1c. index.twig — supprimer `{{ foo }}`

- Ligne 4 : supprimer `<h2>{{ foo }}</h2>`

### 1d. footer.twig — ajouter le nom du site

- `Copyright {{ 'now'|date('Y') }}` → `{{ site.name }} &copy; {{ 'now'|date('Y') }}`

### 1e. archive.php + search.php — internationaliser les chaînes PHP

- `'Archive'` → `__('Archive', 'starter-theme')`
- `'Archive: '` → `__('Archive:', 'starter-theme') . ' '`
- `'Search results for '` dans search.php → `__('Search results for', 'starter-theme') . ' '`
- `'timber-starter'` dans author.php → `'starter-theme'`

---

## Axe 2 — Préparation i18n (toujours actif, pas de question)

> **Stratégie multilangue :** Le thème est **toujours** translation-ready par défaut.
> Pas de question dans le setup — c'est un standard de qualité, pas une option.
>
> **Ce que ça signifie concrètement :** Chaque texte visible par l'utilisateur final
> (labels, messages, boutons) est entouré de `{{ __('texte', 'starter-theme') }}`
> dans les templates Twig, ou de `__('texte', 'starter-theme')` dans les fichiers PHP.
> C'est la fonction WordPress de traduction. Elle retourne le texte tel quel si aucune
> traduction n'est installée. Le jour où on installe WPML ou Polylang, ces fonctions
> détectent automatiquement toutes les chaînes et permettent de les traduire.
>
> **Pas de changement structurel nécessaire** pour le multilangue : les plugins
> gèrent tout au niveau base de données (contenu, URLs, switcheur de langue).
> Le thème n'a besoin que du text domain + les chaînes wrappées.

### 2a. Infrastructure i18n

- **Nouveau fichier** `src/theme/inc/i18n.php` : `load_theme_textdomain('starter-theme', get_template_directory() . '/languages')`
- **Ajouter** `require_once __DIR__ . '/inc/i18n.php'` dans `functions.php` (après cleanup.php)
- **Ajouter** `Text Domain: starter-theme` et `Domain Path: /languages` dans `style.css`
- **Créer** `src/theme/languages/.gitkeep`

### 2b. Internationaliser les templates Twig

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

---

## Axe 3 — setup.sh résilient

**Fichier :** `bin/setup.sh`

### 3a. Pre-flight checks (avant les questions)

- Vérifier `node`, `npm` disponibles (erreur fatale si absents)
- Vérifier `composer` disponible (warning si absent)
- Le check Docker se fait **après** le choix d'environnement (dans le `case 1)`) : vérifier `docker info` → erreur si Docker daemon pas lancé

### 3b. State file `.setup-state` pour reprendre après échec

- Au démarrage : si `.setup-state` existe → proposer "Reprendre avec les réponses sauvegardées ? [O/n]"
- Si oui : `source .setup-state`, sauter les questions
- Après les questions : sauvegarder toutes les réponses dans `.setup-state`
- À la fin (succès) : supprimer `.setup-state`
- Sur erreur : garder `.setup-state` + afficher message "Re-run pour reprendre"
- Ajouter `.setup-state` au `.gitignore`

### 3c. Idempotence

- `.env` : demander confirmation si le fichier existe déjà
- Docker : vérifier si les containers tournent déjà avant de lancer `docker compose up`

### 3d. Configurer WP via WP-CLI

- Ajouter `$WP_CLI option update blogname "$PROJECT_NAME"` dans la section WP-CLI

### 3e. Remplacer le text domain dans tous les fichiers

- `sed` sur `src/theme/**/*.php` et `src/templates/**/*.twig` : remplacer `'starter-theme'` par `'$PROJECT_NAME'`

---

## Ordre d'implémentation

1. **Nettoyage contenu hardcodé** (1a-1e) — supprimer démo Timber, fixer footer, i18n des PHP
2. **Infrastructure i18n + internationalisation templates** (2a-2b) — créer i18n.php, languages/, wrapper toutes les chaînes
3. **setup.sh résilient** (3a-3e) — preflight, state file, idempotence, text domain dynamique

---

## Fichiers modifiés

| Fichier                                        | Action                                                              |
| ---------------------------------------------- | ------------------------------------------------------------------- |
| `src/theme/src/StarterSite.php`                | Supprimer démo (foo/stuff/notes/myfoo), fixer text domain           |
| `src/theme/index.php`                          | Supprimer `foo => bar`                                              |
| `src/theme/functions.php`                      | Ajouter require i18n.php                                            |
| `src/theme/style.css`                          | Ajouter Text Domain + Domain Path                                   |
| `src/theme/archive.php`                        | Internationaliser les titres                                        |
| `src/theme/search.php`                         | Internationaliser le titre                                          |
| `src/theme/author.php`                         | Fixer text domain (`timber-starter` → `starter-theme`)              |
| `src/theme/inc/i18n.php`                       | **Nouveau** — load_theme_textdomain                                 |
| `src/theme/languages/.gitkeep`                 | **Nouveau** — dossier traductions                                   |
| `src/templates/layouts/base.twig`              | Ajouter text domain, wrapper fallback                               |
| `src/templates/partials/footer.twig`           | Ajouter `site.name`                                                 |
| `src/templates/templates/index.twig`           | Supprimer `{{ foo }}`                                               |
| `src/templates/templates/single.twig`          | Wrapper "By", "comments", "closed"                                  |
| `src/templates/templates/404.twig`             | Wrapper message erreur                                              |
| `src/templates/templates/single-password.twig` | Wrapper labels                                                      |
| `src/templates/partials/comment-form.twig`     | Wrapper 9 strings                                                   |
| `src/templates/partials/comment.twig`          | Wrapper "says", "replies"                                           |
| `src/templates/partials/pagination.twig`       | Wrapper 4×2 labels                                                  |
| `src/templates/partials/tease-post.twig`       | Wrapper "Keep reading"                                              |
| `bin/setup.sh`                                 | Preflight, state file, idempotence, text domain, blogname via WP-CLI |
| `.gitignore`                                   | Ajouter `.setup-state`                                              |

---

## Vérification

1. **Ouvrir le site** → vérifier qu'il n'y a plus de "bar", que le footer affiche le nom du site
2. **Vérifier les templates** → aucune chaîne anglaise brute, tout wrappé dans `__()`
3. **Lancer `npm run setup`** en mode Docker → vérifier le flow complet
4. **Interrompre le setup** (Ctrl+C après les questions) → relancer → vérifier que "Reprendre ?" fonctionne
5. **Lancer sans Docker Desktop** → vérifier le message d'erreur clair avant les questions
6. **Vérifier le titre WP** → correspond au PROJECT_NAME choisi
