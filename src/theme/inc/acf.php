<?php
/**
 * ACF configuration
 *
 * Sets up ACF JSON save/load paths.
 */

namespace App;

/**
 * Set the path where ACF saves field group JSON files.
 */
add_filter('acf/settings/save_json', function () {
	return get_template_directory() . '/acf-json';
});

/**
 * Set the path(s) where ACF loads field group JSON files from.
 */
add_filter('acf/settings/load_json', function ($paths) {
	// Remove the default path
	unset($paths[0]);

	$paths[] = get_template_directory() . '/acf-json';

	return $paths;
});
