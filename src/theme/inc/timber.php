<?php
/**
 * Timber configuration
 *
 * Sets up Timber view paths to use the templates/ directory.
 */

namespace App;

use Timber\Timber;

/**
 * Set the directories where Timber looks for Twig templates.
 * By default Timber looks in the theme's "views" directory.
 * We override this to use "templates/" instead.
 */
add_filter('timber/locations', function ($paths) {
	$paths[] = [get_template_directory() . '/templates'];
	return $paths;
});
