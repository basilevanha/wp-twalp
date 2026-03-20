# WP Boilerplate

A modern WordPress development boilerplate with **Timber** (Twig), **Vite** (HMR), and **Docker** — all wired together with an interactive setup CLI.

Choose your stack: **SCSS** or **Tailwind**, **Vanilla JS** or **Alpine.js**.

Works with **npm**, **pnpm**, **yarn**, and **bun** — auto-detected.

**One command to start:**

```bash
npm run setup    # or: pnpm run setup / yarn setup / bun run setup
```

WordPress installed, theme activated, dev server ready. No manual configuration.

---

## What's included

| Tool | Role |
|------|------|
| **Vite 6** | HMR, CSS/JS compilation, bundling |
| **Timber 2** | Twig templating for WordPress |
| **SCSS** or **Tailwind** | CSS framework (chosen during setup) |
| **Vanilla JS** or **Alpine.js** | JS interactions (chosen during setup) |
| **ACF** | Custom fields with JSON sync (optional) |
| **Docker** | WordPress + MySQL + phpMyAdmin |
| **WP-CLI** | Automated WordPress setup |

## Project structure

```
wp-boilerplate/
├── bin/
│   ├── setup.sh          # Interactive setup CLI
│   ├── dev.js            # Dev orchestrator (sync + Vite + Docker)
│   ├── sync.js           # File sync src/ → theme
│   ├── import.sh         # Database import with URL fix
│   └── reset.sh          # Full project reset with confirmation
├── docker/
│   └── docker-compose.yml
├── src/                   # ← Your workspace
│   ├── js/main.js        # JS entry point
│   ├── scss/             # SCSS (if chosen) — or src/css/ for Tailwind
│   ├── templates/        # Twig templates (layouts, pages, partials)
│   ├── theme/            # PHP (functions.php, inc/, StarterSite.php)
│   ├── acf-json/         # ACF field groups (git-versioned)
│   ├── fonts/            # Web fonts
│   └── images/           # Static images
├── public/                # WordPress installation (gitignored)
├── vite.config.js
├── composer.json          # Timber
└── package.json           # Vite + dependencies
```

**Key principle:** `src/` is what you code and commit. `public/` is the WordPress installation (gitignored). Build tools live at the root, not in the theme.

---

## Quick start

### Prerequisites

- [Node.js](https://nodejs.org/) (v18+)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Composer](https://getcomposer.org/)
- A package manager: npm (included with Node), [pnpm](https://pnpm.io/), [yarn](https://yarnpkg.com/), or [bun](https://bun.sh/)

### Setup

```bash
git clone https://github.com/your-username/wp-boilerplate.git my-project
cd my-project
npm run setup
```

The interactive CLI walks you through 4 steps:

1. **Project name** — used as theme slug, text domain, and Docker project name
2. **Docker** — DB credentials (auto-generated), ports (auto-detected), optional database dump import
3. **WordPress** — automatic setup (admin credentials, language, homepage type, clean defaults) or vanilla (manual setup via browser)
4. **Features** — ACF (yes/no), CSS framework (SCSS/Tailwind), JS interactions (Vanilla/Alpine)

Then it automatically:
- Generates `.env`
- Installs dependencies (Composer + your package manager)
- Configures CSS/JS framework (installs Tailwind/Alpine if selected)
- Starts Docker containers
- Installs WordPress via WP-CLI (if automatic mode)
- Activates your theme
- Sets up homepage (latest posts or static page)
- Removes default themes, plugins, and sample content
- Sets permalinks to `/%postname%/`
- Launches the dev server

### Development

The dev server starts automatically after setup. To start it manually:

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

- Edit `.scss` or `.css` → CSS hot-reloaded instantly (no page refresh)
- Edit `.twig` or `.php` → full page reload
- Docker containers started automatically if needed
- Vite finds a free port if 5173 is busy

### Other commands

```bash
npm run build    # Production build (hashed CSS/JS + manifest)
npm run dump     # Export database to database/dump-YYYYMMDD-HHMMSS.sql
npm run import   # Import a database dump (interactive file picker)
npm run stop     # Stop Docker containers
npm run reset    # Delete everything (with confirmation + optional dump)
```

---

## CSS framework

The setup CLI lets you choose between SCSS and Tailwind.

### SCSS (default)

Traditional preprocessor with a BEM-friendly structure:

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

Edit `.scss` files → Vite compiles and hot-reloads CSS instantly (no page refresh).

### Tailwind

Utility-first CSS. The setup installs `tailwindcss` + `@tailwindcss/vite`, removes SCSS, and creates:

```
src/css/
└── main.css            # @import "tailwindcss" + @source for .twig files
```

Style directly in your `.twig` templates:

```twig
<button class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">
  {{ __('Contact', 'my-theme') }}
</button>
```

Tailwind scans all `.twig` files and only outputs the CSS classes you actually use. Copy-paste components from [Flowbite](https://flowbite.com/), [HyperUI](https://www.hyperui.dev/), [DaisyUI](https://daisyui.com/), or any Tailwind component library.

> **Note:** with Tailwind, editing `.twig` files triggers a full page reload (not HMR) since styles live in the templates.

---

## JS interactions

The setup CLI lets you choose between Vanilla JS and Alpine.js.

### Vanilla JS (default)

Write your own JavaScript in `src/js/main.js`. No framework, full control.

### Alpine.js

Lightweight reactive framework (~14 kB) for UI interactions. Declared directly in HTML/Twig:

```twig
<div x-data="{ open: false }">
  <button @click="open = !open">Menu</button>
  <nav x-show="open" x-transition>
    {{ fn('wp_nav_menu', { theme_location: 'primary' }) }}
  </nav>
</div>
```

Perfect for menus, modals, tabs, accordions, counters — anything that would normally require querySelector + addEventListener boilerplate.

The setup installs `alpinejs` and adds it to `main.js` automatically.

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

In dev mode, changes are watched and synced automatically.

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

## Database management

### Export

```bash
npm run dump
# → database/dump-20260319-143052.sql
```

Dumps are gitignored by default. Each dump is timestamped — you can keep multiple versions.

### Import

Two ways to import a dump:

**During setup** — if dumps exist in `database/`, the setup CLI offers to restore one instead of starting with an empty database:

```
  ℹ  Database dumps found:

  → 1) dump-20260319-143052.sql (2.3 MB)
    2) dump-20260318-091530.sql (1.8 MB)
    3) Fresh install (empty database)

  Choose [3]:
```

**On a running project:**

```bash
npm run import              # Interactive file picker
npm run import -- database/dump-20260319-143052.sql  # Direct path
```

After import, URLs are automatically fixed via `wp search-replace` (serialization-safe).

### Full reset

```bash
npm run dump     # Save your work first
npm run reset    # Confirmation prompt → optional dump → wipe everything
npm run setup    # Start fresh (will offer to restore from dump)
```

The reset asks for confirmation and offers to dump the database before deleting.

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

## Resilient setup

The setup CLI is designed to handle failures gracefully:

- **Pre-flight checks** — verifies Node, package manager, Composer, Docker before starting
- **Resume after failure** — answers are saved to `.setup-state`. If setup crashes, re-run and it offers to resume
- **Port detection** — finds free ports if 8080/8081/5173 are busy
- **Volume detection** — warns if a database already exists for the project name
- **Vanilla mode** — skip WP-CLI configuration and set up WordPress manually via browser
- **Idempotent** — safe to re-run

---

## Package manager support

The boilerplate auto-detects your package manager. Use whichever you prefer:

```bash
npm run setup     # npm
pnpm run setup    # pnpm
yarn setup        # yarn
bun run setup     # bun
```

Detection uses `npm_config_user_agent` (set by all PMs when running scripts), with lock file fallback. All CLI messages adapt to show the correct command for your PM.

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
