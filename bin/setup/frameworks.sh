#!/usr/bin/env bash
# setup/frameworks.sh — CSS/JS framework setup + front-page template generation

# ── CSS Framework ──
if [ "${CSS_FRAMEWORK:-scss}" = "tailwind" ]; then
  info "Setting up Tailwind CSS..."

  (cd "$ROOT_DIR" && "$PM" install -D tailwindcss @tailwindcss/vite 2>/dev/null) || \
  (cd "$ROOT_DIR" && "$PM" install -D tailwindcss @tailwindcss/vite)
  success "Tailwind CSS installed"

  mkdir -p "$ROOT_DIR/src/css"
  cat > "$ROOT_DIR/src/css/main.css" <<'CSSEOF'
@import "tailwindcss";
@source "../templates/**/*.twig";
CSSEOF
  success "Created src/css/main.css"

  cat > "$ROOT_DIR/vite.config.js" <<'VITEEOF'
import { defineConfig } from 'vite';
import tailwindcss from '@tailwindcss/vite';
import liveReload from 'vite-plugin-live-reload';
import path from 'path';
import { config } from 'dotenv';

config();

const THEME_DIR = process.env.THEME_DIR || './public/wp-content/themes/starter-theme';
const resolvedThemeDir = path.resolve(__dirname, THEME_DIR);

const isProduction = process.env.NODE_ENV === 'production';
const themeBase = '/wp-content/themes/' + path.basename(resolvedThemeDir) + '/dist/';

export default defineConfig({
  plugins: [
    tailwindcss(),
    liveReload([
      `${resolvedThemeDir}/**/*.php`,
      `${resolvedThemeDir}/templates/**/*.twig`,
    ]),
  ],

  root: 'src',
  base: isProduction ? themeBase : '/',

  build: {
    outDir: path.resolve(resolvedThemeDir, 'dist'),
    emptyOutDir: true,
    manifest: true,
    rollupOptions: {
      input: {
        main: path.resolve(__dirname, 'src/js/main.js'),
      },
    },
  },

  server: {
    port: 5173,
    strictPort: false,
    cors: true,
  },
});
VITEEOF
  success "Updated vite.config.js for Tailwind"

  rm -rf "$ROOT_DIR/src/scss"
  success "Removed src/scss/"

  (cd "$ROOT_DIR" && "$PM" uninstall sass 2>/dev/null) || true
  success "Uninstalled sass"

  sedi "s|import '../scss/main.scss';|import '../css/main.css';|" "$ROOT_DIR/src/js/main.js"
  success "Updated main.js import to Tailwind CSS"
fi

# ── JS Framework ──
if [ "${JS_FRAMEWORK:-vanilla}" = "alpine" ]; then
  info "Setting up Alpine.js..."

  (cd "$ROOT_DIR" && "$PM" install alpinejs 2>/dev/null) || \
  (cd "$ROOT_DIR" && "$PM" install alpinejs)
  success "Alpine.js installed"

  cat >> "$ROOT_DIR/src/js/main.js" <<'JSEOF'

// Alpine.js — reactive HTML attributes for UI interactions
import Alpine from 'alpinejs';
window.Alpine = Alpine;
Alpine.start();
JSEOF
  success "Added Alpine.js to main.js"
fi

# ── Generate front-page.twig (if static homepage selected) ──
if [ "${WP_HOMEPAGE:-1}" = "1" ]; then
  FRONT_PAGE_TWIG="$ROOT_DIR/src/templates/templates/front-page.twig"
  CSS="${CSS_FRAMEWORK:-scss}"
  JS="${JS_FRAMEWORK:-vanilla}"

  if [ "$CSS" = "tailwind" ] && [ "$JS" = "alpine" ]; then
    cat > "$FRONT_PAGE_TWIG" <<'TWIGEOF'
{% extends 'layouts/base.twig' %}

{% block content %}
	<div
		x-data="{
			x: 50, y: 50,
			tx: 50, ty: 50,
			scale: 1, tScale: 1,
			init() {
				this.randomTarget()
				this.loop()
			},
			randomTarget() {
				this.tx = 25 + Math.random() * 50
				this.ty = 20 + Math.random() * 60
				this.tScale = 0.85 + Math.random() * 0.3
			},
			loop() {
				this.x += (this.tx - this.x) * 0.008
				this.y += (this.ty - this.y) * 0.008
				this.scale += (this.tScale - this.scale) * 0.008
				if (Math.abs(this.tx - this.x) < 1) this.randomTarget()
				requestAnimationFrame(() => this.loop())
			}
		}" class="relative min-h-[80vh] flex flex-col items-center justify-center overflow-hidden bg-gray-50">
		<div class="pointer-events-none absolute h-[500px] w-[500px] rounded-full bg-gradient-to-br from-indigo-200/60 via-purple-200/40 to-pink-200/60 blur-3xl" :style="`left:${x}%;top:${y}%;transform:translate(-50%,-50%) scale(${scale})`"></div>

		<div class="relative z-10 mx-auto max-w-3xl px-6 py-24 text-center">
			<h1 class="text-5xl font-extrabold tracking-tight text-gray-900 sm:text-6xl">
				{{ post.title }}
			</h1>

			{% if post.content %}
				<div class="mt-6 text-lg leading-relaxed text-gray-600">
					{{ post.content|raw }}
				</div>
			{% endif %}

			<div class="mt-16 grid gap-8 sm:grid-cols-3">
				<div class="rounded-2xl bg-white/70 p-6 shadow-sm backdrop-blur-sm ring-1 ring-gray-900/5">
					<p class="text-3xl font-bold text-indigo-600">Timber</p>
					<p class="mt-2 text-sm text-gray-500">Twig templates</p>
				</div>
				<div class="rounded-2xl bg-white/70 p-6 shadow-sm backdrop-blur-sm ring-1 ring-gray-900/5">
					<p class="text-3xl font-bold text-indigo-600">Tailwind</p>
					<p class="mt-2 text-sm text-gray-500">Utility-first CSS</p>
				</div>
				<div class="rounded-2xl bg-white/70 p-6 shadow-sm backdrop-blur-sm ring-1 ring-gray-900/5">
					<p class="text-3xl font-bold text-indigo-600">Alpine</p>
					<p class="mt-2 text-sm text-gray-500">Reactive interactions</p>
				</div>
			</div>

			<p class="mt-12 text-sm text-gray-400">{{ site.name }} &middot; {{ "now"|date("Y") }}</p>
		</div>
	</div>
{% endblock %}
TWIGEOF

  elif [ "$CSS" = "tailwind" ]; then
    cat > "$FRONT_PAGE_TWIG" <<'TWIGEOF'
{% extends 'layouts/base.twig' %}

{% block content %}
	<div class="min-h-[80vh] flex flex-col items-center justify-center bg-gray-50">
		<div class="mx-auto max-w-3xl px-6 py-24 text-center">
			<h1 class="text-5xl font-extrabold tracking-tight text-gray-900 sm:text-6xl">
				{{ post.title }}
			</h1>

			{% if post.content %}
				<div class="mt-6 text-lg leading-relaxed text-gray-600">
					{{ post.content|raw }}
				</div>
			{% endif %}

			<div class="mt-16 grid gap-8 sm:grid-cols-3">
				<div class="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-gray-900/5">
					<p class="text-3xl font-bold text-indigo-600">Timber</p>
					<p class="mt-2 text-sm text-gray-500">Twig templates</p>
				</div>
				<div class="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-gray-900/5">
					<p class="text-3xl font-bold text-indigo-600">Tailwind</p>
					<p class="mt-2 text-sm text-gray-500">Utility-first CSS</p>
				</div>
				<div class="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-gray-900/5">
					<p class="text-3xl font-bold text-indigo-600">Vite</p>
					<p class="mt-2 text-sm text-gray-500">HMR + build</p>
				</div>
			</div>

			<p class="mt-12 text-sm text-gray-400">{{ site.name }} &middot; {{ "now"|date("Y") }}</p>
		</div>
	</div>
{% endblock %}
TWIGEOF

  elif [ "$JS" = "alpine" ]; then
    cat > "$FRONT_PAGE_TWIG" <<'TWIGEOF'
{% extends 'layouts/base.twig' %}

{% block content %}
	<div class="front-page">
		<div class="front-page__hero">
			<h1 class="front-page__title">{{ post.title }}</h1>

			{% if post.content %}
				<div class="front-page__content">
					{{ post.content|raw }}
				</div>
			{% endif %}

			<div class="front-page__cards" x-data="{ active: 0 }">
				<div class="front-page__card" :class="{ 'front-page__card--active': active === 0 }" @click="active = 0">
					<p class="front-page__card-title">Timber</p>
					<p class="front-page__card-desc">Twig templates</p>
				</div>
				<div class="front-page__card" :class="{ 'front-page__card--active': active === 1 }" @click="active = 1">
					<p class="front-page__card-title">SCSS</p>
					<p class="front-page__card-desc">BEM methodology</p>
				</div>
				<div class="front-page__card" :class="{ 'front-page__card--active': active === 2 }" @click="active = 2">
					<p class="front-page__card-title">Alpine</p>
					<p class="front-page__card-desc">Reactive interactions</p>
				</div>
			</div>

			<p class="front-page__footer">{{ site.name }} &middot; {{ "now"|date("Y") }}</p>
		</div>
	</div>
{% endblock %}
TWIGEOF

  else
    cat > "$FRONT_PAGE_TWIG" <<'TWIGEOF'
{% extends 'layouts/base.twig' %}

{% block content %}
	<div class="front-page">
		<div class="front-page__hero">
			<h1 class="front-page__title">{{ post.title }}</h1>

			{% if post.content %}
				<div class="front-page__content">
					{{ post.content|raw }}
				</div>
			{% endif %}

			<div class="front-page__cards">
				<div class="front-page__card">
					<p class="front-page__card-title">Timber</p>
					<p class="front-page__card-desc">Twig templates</p>
				</div>
				<div class="front-page__card">
					<p class="front-page__card-title">SCSS</p>
					<p class="front-page__card-desc">BEM methodology</p>
				</div>
				<div class="front-page__card">
					<p class="front-page__card-title">Vite</p>
					<p class="front-page__card-desc">HMR + build</p>
				</div>
			</div>

			<p class="front-page__footer">{{ site.name }} &middot; {{ "now"|date("Y") }}</p>
		</div>
	</div>
{% endblock %}
TWIGEOF
  fi

  success "Generated front-page.twig (${CSS} + ${JS})"
else
  # Latest posts — remove front-page files
  rm -f "$ROOT_DIR/src/theme/front-page.php"
  rm -f "$ROOT_DIR/src/templates/templates/front-page.twig"
fi
