# WP Boilerplate

A modern WordPress development boilerplate with **Timber** (Twig), **Vite** (HMR), **SCSS**, and **Docker** — all wired together with an interactive setup CLI.

**One command to start:**

```bash
npm run setup
```

WordPress installed, theme activated, dev server ready. No manual configuration.

---

## What's included

| Tool | Role |
|------|------|
| **Vite 6** | HMR, SCSS compilation, JS bundling |
| **Timber 2** | Twig templating for WordPress |
| **SCSS** | Preprocessor with BEM-friendly structure |
| **ACF** | Custom fields with JSON sync (optional) |
| **Docker** | WordPress + MySQL + phpMyAdmin |
| **WP-CLI** | Automated WordPress setup |

## Project structure

```
wp-boilerplate/
├── bin/
│   ├── setup.sh          # Interactive setup CLI
│   ├── dev.js            # Dev orchestrator (sync + Vite + Docker)
│   └── sync.js           # File sync src/ → theme
├── docker/
│   └── docker-compose.yml
├── src/                   # ← Your workspace
│   ├── js/main.js        # JS entry point
│   ├── scss/             # SCSS (variables, base, components, layouts)
│   ├── templates/        # Twig templates (layouts, pages, partials)
│   ├── theme/            # PHP (functions.php, inc/, StarterSite.php)
│   ├── acf-json/         # ACF field groups (git-versioned)
│   ├── fonts/            # Web fonts
│   └── images/           # Static images
├── public/                # WordPress installation (gitignored)
├── vite.config.js
├── composer.json          # Timber
└── package.json           # Vite, Sass, Chokidar
```

**Key principle:** `src/` is what you code and commit. `public/` is the WordPress installation (gitignored). Build tools live at the root, not in the theme.

---

## Quick start

### Prerequisites

- [Node.js](https://nodejs.org/) (v18+)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Composer](https://getcomposer.org/)

### Setup

```bash
git clone https://github.com/your-username/wp-boilerplate.git my-project
cd my-project
npm run setup
```

The interactive CLI will ask:

1. **Project name** — used as theme slug, text domain, and Docker project name
2. **WordPress admin** — username, password, email, language
3. **Environment** — Docker (recommended), DevKinsta, or existing WP installation
4. **Features** — ACF support (yes/no)

Then it automatically:
- Generates `.env`
- Installs dependencies (Composer + npm)
- Starts Docker containers
- Installs WordPress via WP-CLI
- Activates your theme
- Removes default themes, plugins, and sample content
- Sets permalinks to `/%postname%/`

### Development

```bash
npm run dev
```

```
╔══════════════════════════════════════════╗
║       Development server ready           ║
╠══════════════════════════════════════════╣
║  WordPress :  http://localhost:8080      ║
║  Vite HMR  :  http://localhost:5173      ║
║  phpMyAdmin :  http://localhost:8081      ║
╚══════════════════════════════════════════╝
```

- Edit `.scss` → CSS hot-reloaded instantly (no page refresh)
- Edit `.twig` or `.php` → full page reload
- Docker containers started automatically if needed
- Vite finds a free port if 5173 is busy

### Other commands

```bash
npm run build    # Production build (hashed CSS/JS + manifest)
npm run stop     # Stop Docker containers
npm run reset    # Delete everything (Docker volumes, public/, .env, node_modules, vendor)
```

---

## How it works

### File sync

`src/` is your source of truth. The sync system copies files to the WordPress theme directory:

| Source | Destination |
|--------|------------|
| `src/theme/` | `→ public/wp-content/themes/{name}/` |
| `src/templates/` | `→ themes/{name}/templates/` |
| `src/fonts/` | `→ themes/{name}/assets/fonts/` |
| `src/images/` | `→ themes/{name}/assets/images/` |
| `src/acf-json/` | `→ themes/{name}/acf-json` (symlink) |

In dev mode (`npm run dev`), changes are watched and synced automatically.

### Vite integration

The PHP bridge (`inc/vite.php`) detects the environment:

- **Dev:** reads `dist/hot` file → injects Vite's `@vite/client` for HMR → loads JS/CSS from dev server
- **Prod:** reads `dist/.vite/manifest.json` → enqueues hashed CSS/JS files

### ACF JSON sync

ACF field groups are stored in `src/acf-json/` (versioned in git). A symlink connects the theme to this directory, so changes made in wp-admin are written directly to your repo.

To remove ACF support, answer "no" during setup — the CLI removes all related files.

### Docker isolation

Each project gets its own:
- **Container names** — prefixed with project slug (`my-site-wordpress-1`)
- **Database volume** — `{slug}_db_data`
- **Network** — `{slug}_default`
- **DB credentials** — unique name/user/password derived from slug

Multiple projects can run simultaneously on different ports.

---

## Environments

### Docker (recommended)

Everything is included. The setup CLI:
- Creates containers (WordPress + MySQL 8 + phpMyAdmin)
- Finds free ports automatically (8080, 8081, or next available)
- Installs WordPress via WP-CLI
- Detects existing database volumes to avoid conflicts

### DevKinsta

Point the boilerplate to your DevKinsta site:

```bash
npm run setup
# Choose "DevKinsta"
# Enter path: ~/DevKinsta/public/my-site
```

The sync system copies your theme directly into DevKinsta's theme directory.

### Existing WordPress

Point to any WordPress installation:

```bash
npm run setup
# Choose "Existing WordPress installation"
# Enter path: /path/to/wordpress
```

---

## Templates

Twig templates follow the Timber structure:

```
src/templates/
├── layouts/
│   └── base.twig              # HTML skeleton (head, body, footer)
├── templates/
│   ├── index.twig             # Home page
│   ├── single.twig            # Single post
│   ├── page.twig              # Static page
│   ├── archive.twig           # Archive/category
│   ├── search.twig            # Search results
│   ├── 404.twig               # Not found
│   └── single-password.twig   # Password-protected post
└── partials/
    ├── head.twig              # <head> meta tags
    ├── menu.twig              # Navigation
    ├── footer.twig            # Site footer
    ├── comment.twig           # Single comment
    ├── comment-form.twig      # Comment form
    ├── pagination.twig        # Post pagination
    └── tease.twig             # Post teaser/card
```

All UI strings are translation-ready with `{{ __('String', 'text-domain') }}`.

---

## SCSS structure

```
src/scss/
├── main.scss           # Entry point (imports everything)
├── _variables.scss     # Colors, fonts, breakpoints
├── base/
│   ├── _reset.scss     # CSS reset/normalize
│   └── _typography.scss
├── components/         # Button, card, form styles
└── layouts/            # Header, footer, grid styles
```

Imported via `src/js/main.js` — Vite handles the compilation.

---

## Resilient setup

The setup CLI is designed to handle failures gracefully:

- **Pre-flight checks** — verifies Node, npm, Composer, Docker before starting
- **Resume after failure** — answers are saved to `.setup-state`. If setup crashes (e.g., Docker not running), re-run `npm run setup` and it offers to resume
- **Port detection** — finds free ports if 8080/8081/5173 are busy
- **Volume detection** — warns if a database already exists for the project name
- **Idempotent** — safe to re-run

---

## Production build

```bash
npm run build
```

This produces a self-contained theme in `public/wp-content/themes/{name}/` with:
- Compiled and minified CSS/JS with content hashes
- `vendor/` directory (Timber) included
- `manifest.json` for cache-busting
- No dev dependencies or source maps

Deploy the theme directory to any WordPress installation.

---

## License

MIT
