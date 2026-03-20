#!/usr/bin/env bash
# setup/frameworks.sh — Generate front-page template (if static homepage selected)

if [ "${WP_HOMEPAGE:-1}" = "1" ]; then
  FRONT_PAGE_TWIG="$ROOT_DIR/src/templates/templates/front-page.twig"

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

  success "Generated front-page template"
else
  # Latest posts — remove front-page files
  rm -f "$ROOT_DIR/src/theme/front-page.php"
  rm -f "$ROOT_DIR/src/templates/templates/front-page.twig"
fi
