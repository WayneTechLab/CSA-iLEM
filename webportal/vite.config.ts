import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { resolve } from 'path'

const systemxLanPort = process.env.SYSTEMX_LAN_PORT ?? '7331'

function localSession(): Plugin {
  return {
    name: 'csa-iem-local-session',
    apply: 'serve',
    configureServer(server) {
      const origin = process.env.CSA_LOCAL_VITE_ORIGIN
      const fixture = process.env.CSA_LOCAL_OWNER
      if (!origin || !fixture || !/^http:\/\/127\.0\.0\.1:\d+$/.test(origin))
        return
      server.middlewares.use((req, res, next) => {
        const status = req.url === '/__csa_status'
        const owner = req.url === '/__csa_local_owner'
        if (!status && !owner) return next()
        if (
          req.method !== 'GET' ||
          req.headers.host !== new URL(origin).host ||
          (owner && req.headers['sec-fetch-site'] !== 'same-origin')
        ) {
          res.statusCode = 403
          return res.end()
        }
        res.setHeader('Cache-Control', 'no-store')
        res.setHeader('Content-Type', 'application/json')
        res.end(status ? '{"project":"demo-csa-iem"}' : fixture)
      })
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss(), localSession()],
  server: {
    host: '127.0.0.1',
    port: 5184,
    strictPort: true,
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
          if (
            id.includes('node_modules/react') ||
            id.includes('node_modules/react-dom')
          ) {
            return 'react'
          }
          if (
            id.includes('/node_modules/@firebase/firestore/') ||
            id.includes('/node_modules/firebase/firestore/')
          ) {
            return 'firebase-firestore'
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
