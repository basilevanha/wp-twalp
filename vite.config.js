import { defineConfig } from 'vite';
import liveReload from 'vite-plugin-live-reload';
import path from 'path';
import { config } from 'dotenv';

config();

const THEME_DIR = process.env.THEME_DIR || './public/wp-content/themes/starter-theme';
const resolvedThemeDir = path.resolve(__dirname, THEME_DIR);

export default defineConfig({
  plugins: [
    // Watch PHP and Twig files in the theme directory for live reload
    liveReload([
      `${resolvedThemeDir}/**/*.php`,
      `${resolvedThemeDir}/templates/**/*.twig`,
    ]),
  ],

  root: 'src',

  base: '/wp-content/themes/' + path.basename(resolvedThemeDir) + '/dist/',

  build: {
    outDir: path.resolve(resolvedThemeDir, 'dist'),
    emptyOutDir: true,
    manifest: true,
    rollupOptions: {
      input: {
        main: path.resolve(__dirname, 'src/js/main.js'),
      },
    },
  },

  server: {
    port: 5173,
    strictPort: true,
    cors: true,
    // Allow access from the WordPress site
    origin: 'http://localhost:5173',
  },

  css: {
    preprocessorOptions: {
      scss: {
        api: 'modern-compiler',
      },
    },
  },
});
