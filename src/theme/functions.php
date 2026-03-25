<?php

/**
 * Functions and definitions
 *
 * @link https://developer.wordpress.org/themes/basics/theme-functions/
 * @link https://github.com/basilevanha/wp-twalp
 */

namespace App;

use Timber\Timber;

// Load Composer autoload from boilerplate root.
// In dev: generated autoload-path.php points to the repo root's vendor/.
// In prod: vendor/ is bundled inside the theme.
if (file_exists(__DIR__ . '/autoload-path.php')) {
	$autoload = require __DIR__ . '/autoload-path.php';
} else {
	$autoload = __DIR__ . '/vendor/autoload.php';
}

if (file_exists($autoload)) {
	require_once $autoload;
}

// Initialize Timber.
Timber::init();

// Load theme classes.
require_once __DIR__ . '/src/StarterSite.php';

// Load theme configuration.
require_once __DIR__ . '/inc/timber.php';
require_once __DIR__ . '/inc/vite.php';
require_once __DIR__ . '/inc/cleanup.php';
require_once __DIR__ . '/inc/i18n.php';
require_once __DIR__ . '/inc/acf.php';

// Initialize the theme.
new StarterSite();
