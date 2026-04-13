# WP TWALP Boilerplate

[![CI](https://github.com/basilevanha/wp-twalp/actions/workflows/ci.yml/badge.svg)](https://github.com/basilevanha/wp-twalp/actions/workflows/ci.yml)

A modern WordPress development boilerplate with **Timber** (Twig), **Tailwind CSS**, **Alpine.js**, **Vite** (HMR), and **Docker** — all wired together with an interactive setup CLI.

Works with **npm**, **pnpm**, **yarn**, and **bun** — auto-detected.

![Setup demo](docs/demo.gif)

**One command to start:**

```bash
npm run setup    # or: pnpm run setup / yarn setup / bun run setup
```

WordPress installed, theme activated, dev server ready. No manual configuration.

---

## What's included

| Tool               | Role                                                |
| ------------------ | --------------------------------------------------- |
| **Tailwind CSS 4** | Utility-first CSS, scans `.twig` templates          |
| **Alpine.js**      | Reactive UI interactions (~14 kB), declared in HTML |
| **Vite 6**         | HMR, CSS/JS compilation, bundling                   |
| **Timber 2**       | Twig templating for WordPress                       |
| **ACF**            | Custom fields with JSON sync (optional)             |
| **Docker**         | WordPress + MySQL + phpMyAdmin                      |
| **WP-CLI**         | Automated WordPress setup                           |

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
│   ├── js/main.js        # JS entry point (imports CSS + Alpine)
│   ├── css/main.css      # Tailwind entry point
│   ├── views/            # Twig templates (layouts, pages, partials)
│   ├── theme/            # PHP (functions.php, inc/, StarterSite.php)
│   ├── acf-json/         # ACF field groups (git-versioned)
│   ├── fonts/            # Web fonts
│   └── images/           # Static images
├── public/                # WordPress installation (gitignored)
├── vite.config.js
├── composer.json          # Timber
└── package.json           # Vite, Tailwind, Alpine
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
# Via GitHub (recommended — creates your own repo from the template)
# Click "Use this template" on https://github.com/basilevanha/wp-twalp
# then clone your new repo:
git clone https://github.com/you/my-project.git
cd my-project
npm run setup
```

Or via CLI:

```bash
gh repo create my-project --template basilevanha/wp-twalp --clone
cd my-project
npm run setup
```

The interactive CLI walks you through 3 steps:

1. **Project** — site name, slug (auto-derived), DB credentials, optional dump import
2. **WordPress** — automatic setup (admin, language, homepage, clean defaults) or vanilla (manual via browser)
3. **Plugins** — ACF (yes/no)

Then it automatically:

- Generates `.env`
- Installs dependencies (Composer + your package manager)
- Starts Docker containers
- Installs WordPress via WP-CLI (if automatic mode)
- Activates your theme (includes a default front-page template)
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
║  phpMyAdmin :  http://localhost:8081     ║
╚══════════════════════════════════════════╝
```

- Edit `.twig` → Tailwind rebuilds CSS + full page reload
- Edit `.css` → CSS hot-reloaded instantly (no page refresh)
- Edit `.php` → full page reload
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

## Styling with Tailwind

Style directly in your `.twig` templates:

```twig
<button class="px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:opacity-90">
  {{ __('Contact', 'wp-twalp') }}
</button>
```

Tailwind scans all `.twig` files and only outputs the CSS classes you actually use. Copy-paste components from [Flowbite](https://flowbite.com/), [HyperUI](https://www.hyperui.dev/), [DaisyUI](https://daisyui.com/), or any Tailwind component library.

### Design system

The boilerplate includes a ready-to-use design system in `src/css/main.css` based on semantic color tokens:

| Token                       | Usage                                 |
| --------------------------- | ------------------------------------- |
| `primary`                   | Brand color — buttons, links, accents |
| `secondary`                 | Subtle backgrounds, secondary actions |
| `muted`                     | Disabled states, placeholders         |
| `destructive`               | Errors, delete actions                |
| `success` / `warning`       | Feedback states                       |
| `card`                      | Card backgrounds                      |
| `border` / `input` / `ring` | Form elements, borders                |

All colors use the **OKLCH** color space for perceptual uniformity. Dark theme is supported via the `.dark` class on `<html>`.

Use them as Tailwind classes: `bg-primary`, `text-muted-foreground`, `border-border`, `ring-ring`, etc. To customize the palette, edit the CSS custom properties in `:root` and `.dark`.

---

## Interactions with Alpine.js

Declare reactive behavior directly in your Twig templates:

```twig
<div x-data="{ open: false }">
  <button @click="open = !open">Menu</button>
  <nav x-show="open" x-transition>
    {{ fn('wp_nav_menu', { theme_location: 'primary' }) }}
  </nav>
</div>
```

Perfect for menus, modals, tabs, accordions — anything that would normally require querySelector + addEventListener boilerplate. Alpine is loaded globally via `main.js`.

---

## How it works

### File sync

`src/` is your source of truth. The sync system copies files to the WordPress theme directory:

| Source           | Destination                          |
| ---------------- | ------------------------------------ |
| `src/theme/`     | `→ public/wp-content/themes/{name}/` |
| `src/views/`     | `→ themes/{name}/views/`             |
| `src/fonts/`     | `→ themes/{name}/assets/fonts/`      |
| `src/images/`    | `→ themes/{name}/assets/images/`     |
| `src/acf-json/`  | `→ themes/{name}/acf-json` (Docker bind mount) |

In dev mode, changes are watched and synced automatically.

### Vite integration

The PHP bridge (`inc/vite.php`) detects the environment:

- **Dev:** reads `dist/hot` file → injects Vite's `@vite/client` for HMR → loads JS/CSS from dev server
- **Prod:** reads `dist/.vite/manifest.json` → enqueues hashed CSS/JS files

### ACF JSON sync

ACF field groups are stored in `src/acf-json/` (versioned in git). Docker bind-mounts this directory into the theme's `acf-json/`, so changes made in wp-admin are written directly to your repo.

To remove ACF support, answer "no" during setup — the CLI removes all related files.

### Docker isolation

Each project gets its own:

- **Container names** — prefixed with project slug (`wp-twalp-wordpress-1`)
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

Dumps are gitignored by default. Each dump is timestamped.

### Import

Two ways to import a dump:

**During setup** — if dumps exist in `database/`, the setup CLI offers to restore one instead of starting with an empty database.

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

---

## Templates

Twig templates follow the Timber structure:

```
src/views/
├── layouts/
│   └── base.twig              # HTML skeleton (head, body, footer)
├── templates/
│   ├── front-page.twig        # Homepage (removed if "latest posts" chosen)
│   ├── index.twig             # Blog / fallback
│   ├── single.twig            # Single post
│   ├── page.twig              # Static page
│   ├── archive.twig           # Archive/category
│   ├── search.twig            # Search results
│   ├── author.twig            # Author archive
│   ├── 404.twig               # Not found
│   └── single-password.twig   # Password-protected post
└── partials/
    ├── head.twig              # <head> meta tags
    ├── menu.twig              # Navigation
    ├── footer.twig            # Site footer
    ├── comment.twig           # Single comment
    ├── comment-form.twig      # Comment form
    ├── pagination.twig        # Post pagination
    ├── tease.twig             # Post teaser/card
    └── tease-post.twig        # Post-specific teaser
```

All UI strings are translation-ready with `{{ __('String', 'text-domain') }}`.

---

## Resilient setup

- **Pre-flight checks** — verifies Node, package manager, Composer, Docker before starting
- **Resume after failure** — answers are saved to `.setup-state`. If setup crashes, re-run and it offers to resume
- **Port detection** — finds free ports if 8080/8081/5173 are busy
- **Volume detection** — warns if a database already exists for the project name
- **Vanilla mode** — skip WP-CLI configuration and set up WordPress manually via browser

---

## Package manager support

Auto-detected. Use whichever you prefer:

```bash
npm run setup     # npm
pnpm run setup    # pnpm
yarn setup        # yarn
bun run setup     # bun
```

All CLI messages adapt to show the correct command for your PM.

---

## Production build

```bash
npm run build
```

Produces a self-contained theme with:

- Compiled and minified CSS/JS with content hashes
- `vendor/` directory (Timber) included
- `manifest.json` for cache-busting
- No dev dependencies or source maps

Deploy the theme directory to any WordPress installation.

### Testing the production build locally

In dev, Vite injects CSS through the JS module graph to enable HMR — which causes a brief flash of unstyled content on first load. This is expected and only happens in dev. To verify the production output behaves correctly:

```bash
# Stop the dev server first (Ctrl+C) so dist/hot is removed
npm run build
```

Then reload the site at `http://localhost:8080`. The PHP bridge detects the absence of `dist/hot` and switches to manifest mode, enqueuing hashed CSS/JS the standard WordPress way — no FOUC. Run `npm run dev` again to return to development.

---

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)
