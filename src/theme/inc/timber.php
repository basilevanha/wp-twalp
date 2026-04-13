<?php
/**
 * Timber configuration
 *
 * Sets up Timber view paths to use the views/ directory.
 */

namespace App;

use Timber\Timber;

/**
 * Set the directories where Timber looks for Twig templates.
 */
add_filter('timber/locations', function ($paths) {
	$paths[] = [get_template_directory() . '/views'];
	return $paths;
});
