import { useEffect, useState, type ReactNode } from 'react'
import { onIdTokenChanged } from 'firebase/auth'
import { doc, onSnapshot } from 'firebase/firestore'
import { auth, db } from '@/config/firebase'
import { Session } from './useSession'
import type { ContextType } from 'react'

export function SessionProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<ContextType<typeof Session>>({
    user: null,
    verified: false,
    level: 0,
    loading: true,
  })

  useEffect(() => {
    let stop = () => {}
    const unsubscribe = onIdTokenChanged(auth, (user) => {
      stop()
      const verified = user?.emailVerified === true
      const base = { user, verified, level: user ? 1 : 0, loading: false }
      if (!user || !verified) {
        setState(base)
        return
      }
      setState({ ...base, loading: true })
      stop = onSnapshot(
        doc(db, 'roles', user.uid),
        { includeMetadataChanges: true },
        (snapshot) => {
          const n = snapshot.data()?.level
          setState({
            ...base,
            level:
              !snapshot.metadata.fromCache &&
              Number.isInteger(n) &&
              n >= 1 &&
              n <= 5
                ? n
                : 1,
          })
        },
        () => setState(base),
      )
    })
    return () => {
      stop()
      unsubscribe()
    }
  }, [])

  return <Session.Provider value={state}>{children}</Session.Provider>
}
