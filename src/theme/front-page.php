<?php
/**
 * The front page template.
 *
 * Used when a static page is set as the front page.
 *
 * @link https://developer.wordpress.org/themes/basics/template-hierarchy/
 */

namespace App;

use Timber\Timber;

$context = Timber::context();

Timber::render( 'templates/front-page.twig', $context );
