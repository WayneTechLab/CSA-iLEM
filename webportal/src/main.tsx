import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { AppRouter } from './router'
import './index.css'
import { SessionProvider } from './portal/session'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <SessionProvider><AppRouter /></SessionProvider>
  </StrictMode>,
)
