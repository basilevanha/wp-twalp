<?php
/**
 * WordPress cleanup
 *
 * Removes unnecessary default WordPress output.
 */

namespace App;

/**
 * Clean up wp_head output.
 */
add_action('after_setup_theme', function () {
	// Remove WP emoji scripts and styles
	remove_action('wp_head', 'print_emoji_detection_script', 7);
	remove_action('wp_print_styles', 'print_emoji_styles');
	remove_action('admin_print_scripts', 'print_emoji_detection_script');
	remove_action('admin_print_styles', 'print_emoji_styles');

	// Remove WP version from head
	remove_action('wp_head', 'wp_generator');

	// Remove wlwmanifest link
	remove_action('wp_head', 'wlwmanifest_link');

	// Remove RSD link
	remove_action('wp_head', 'rsd_link');

	// Remove shortlink
	remove_action('wp_head', 'wp_shortlink_wp_head');

	// Remove REST API link
	remove_action('wp_head', 'rest_output_link_wp_head');

	// Remove oEmbed discovery links
	remove_action('wp_head', 'wp_oembed_add_discovery_links');
});

/**
 * Disable WordPress emojis completely.
 */
add_filter('emoji_svg_url', '__return_false');

/**
 * Remove WordPress version from RSS feeds.
 */
add_filter('the_generator', '__return_empty_string');
