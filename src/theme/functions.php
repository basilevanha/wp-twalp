<?php

/**
 * Functions and definitions
 *
 * @link https://developer.wordpress.org/themes/basics/theme-functions/
 * @link https://github.com/timber/starter-theme
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

// Load theme configuration.
require_once __DIR__ . '/inc/timber.php';
require_once __DIR__ . '/inc/vite.php';
require_once __DIR__ . '/inc/acf.php';
require_once __DIR__ . '/inc/cleanup.php';

// Initialize the theme.
new StarterSite();
