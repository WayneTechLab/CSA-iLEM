import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { resolve } from 'path'

const systemxLanPort = process.env.SYSTEMX_LAN_PORT ?? '7331'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    host: '127.0.0.1',
    port: 5173,
    proxy: {
      '/__systemx': {
        target: `http://127.0.0.1:${systemxLanPort}`,
        changeOrigin: true,
        rewrite: (requestPath) => requestPath.replace(/^\/__systemx\/?/, '/'),
      },
    },
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },
  build: {
    sourcemap: false,
    reportCompressedSize: false,
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('node_modules/react') || id.includes('node_modules/react-dom')) {
            return 'react'
          }
          if (id.includes('node_modules/firebase')) {
            return 'firebase'
          }
          return undefined
        },
      },
    },
  },
})
