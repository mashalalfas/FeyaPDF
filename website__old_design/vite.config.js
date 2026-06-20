import { defineConfig } from 'vite';

export default defineConfig({
  root: '.',
  publicDir: 'assets',
  server: {
    host: true,
    port: 5173,
    open: false
  },
  build: {
    outDir: 'dist',
    target: 'es2020',
    minify: 'esbuild',
    sourcemap: false,
    rollupOptions: {
      output: {
        manualChunks: {
          three: ['three'],
          gsap: ['gsap']
        }
      }
    }
  }
});
