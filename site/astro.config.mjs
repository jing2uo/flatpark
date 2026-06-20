// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// outDir is overridable so the publish pipeline (and tests) can target any
// location; defaults to the repo's shared out/site.
export default defineConfig({
  outDir: process.env.SITE_OUT_DIR || '../out/site',
  output: 'static',
  vite: {
    plugins: [tailwindcss()],
  },
});
