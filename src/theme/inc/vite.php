<?php
/**
 * Vite asset helper
 *
 * Enqueues Vite dev server assets in development,
 * or hashed production assets from manifest.json.
 */

namespace App;

/**
 * Check if Vite dev server is running.
 */
function vite_is_dev(): bool {
	$dev_server = defined('VITE_DEV_SERVER') ? VITE_DEV_SERVER : 'http://localhost:5173';

	// Check for the hot file (created by sync.js in dev mode)
	$hot_file = get_template_directory() . '/dist/hot';
	return file_exists($hot_file);
}

/**
 * Get the Vite dev server URL.
 */
function vite_dev_server_url(): string {
	$hot_file = get_template_directory() . '/dist/hot';
	if (file_exists($hot_file)) {
		return trim(file_get_contents($hot_file));
	}
	return 'http://localhost:5173';
}

/**
 * Enqueue Vite assets.
 */
function vite_enqueue_assets(): void {
	if (vite_is_dev()) {
		$dev_url = vite_dev_server_url();

		// Vite client for HMR
		add_action('wp_head', function () use ($dev_url) {
			echo '<script type="module" src="' . esc_url($dev_url . '/@vite/client') . '"></script>' . "\n";
		}, 1);

		// Main entry point
		wp_enqueue_script_tag_attributes(function ($attributes) {
			$attributes['type'] = 'module';
			return $attributes;
		});

		wp_enqueue_script(
			'starter-theme-main',
			$dev_url . '/js/main.js',
			[],
			null,
			true
		);
	} else {
		// Production: read manifest.json
		$manifest_path = get_template_directory() . '/dist/.vite/manifest.json';

		if (!file_exists($manifest_path)) {
			return;
		}

		$manifest = json_decode(file_get_contents($manifest_path), true);

		// CSS
		if (isset($manifest['js/main.js']['css'])) {
			foreach ($manifest['js/main.js']['css'] as $index => $css_file) {
				wp_enqueue_style(
					'starter-theme-style-' . $index,
					get_template_directory_uri() . '/dist/' . $css_file,
					[],
					null
				);
			}
		}

		// JS
		if (isset($manifest['js/main.js']['file'])) {
			wp_enqueue_script(
				'starter-theme-main',
				get_template_directory_uri() . '/dist/' . $manifest['js/main.js']['file'],
				[],
				null,
				true
			);
		}
	}
}

add_action('wp_enqueue_scripts', __NAMESPACE__ . '\\vite_enqueue_assets');
