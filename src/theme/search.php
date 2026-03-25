<?php
/**
 * Search results page
 *
 * @link https://developer.wordpress.org/themes/basics/template-hierarchy/
 */

namespace App;

use Timber\Timber;

$templates = [ 'templates/search.twig', 'templates/archive.twig', 'templates/index.twig' ];

$context = Timber::context(
	[
		'title' => __( 'Search results for', 'wp-twalp' ) . ' ' . esc_html( get_search_query() ),
	]
);

Timber::render( $templates, $context );
