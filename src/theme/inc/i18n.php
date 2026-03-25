<?php
/**
 * Internationalization (i18n) setup
 *
 * Loads the theme text domain for translations.
 */

namespace App;

add_action( 'after_setup_theme', function () {
	load_theme_textdomain( 'wp-twalp', get_template_directory() . '/languages' );
} );
