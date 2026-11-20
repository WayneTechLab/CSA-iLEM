import { createContext, useContext } from 'react'
import type { User } from 'firebase/auth'

export const Session = createContext<{
  user: User | null
  verified: boolean
  level: number
  loading: boolean
}>({ user: null, verified: false, level: 0, loading: true })

export function useSession() {
  return useContext(Session)
}
