#!/usr/bin/env bash
# setup/frameworks.sh — Remove front-page files if not needed

if [ "${WP_HOMEPAGE:-1}" != "1" ]; then
  rm -f "$ROOT_DIR/src/theme/front-page.php"
  rm -f "$ROOT_DIR/src/views/templates/front-page.twig"
fi
