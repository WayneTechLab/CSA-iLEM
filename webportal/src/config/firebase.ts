import { initializeApp } from 'firebase/app'
import { connectAuthEmulator, getAuth } from 'firebase/auth'
import { connectFirestoreEmulator, getFirestore } from 'firebase/firestore'
import { connectFunctionsEmulator, getFunctions } from 'firebase/functions'

const prod = {
  apiKey: 'AIzaSyBJT7oBs9hTxHVcNA81Ct7SFn3a3DgyqmU',
  authDomain: 'csa-ilem.firebaseapp.com',
  projectId: 'csa-ilem',
  storageBucket: 'csa-ilem.firebasestorage.app',
  messagingSenderId: '926115230243',
  appId: '1:926115230243:web:b2d3ffac08baa20a71b796',
}

function resolveLocalConfig() {
  const env = import.meta.env
  const auth = env.VITE_CSA_LOCAL_AUTH
  const firestore = env.VITE_CSA_LOCAL_FIRESTORE
  const functions = env.VITE_CSA_LOCAL_FUNCTIONS
  if (
    env.VITE_CSA_LOCAL_PROJECT !== 'demo-csa-iem' ||
    ![auth, firestore, functions].every((endpoint) =>
      /^127\.0\.0\.1:\d+$/.test(endpoint ?? ''),
    )
  ) {
    throw new Error('Start the CSA-iEM portal with npm run dev:local.')
  }
  return { auth, firestore, functions }
}

const local = import.meta.env.DEV ? resolveLocalConfig() : null
const options = local
  ? {
      apiKey: 'demo-local-key',
      authDomain: local.auth,
      projectId: 'demo-csa-iem',
      appId: '1:123:web:local',
    }
  : prod
export const app = initializeApp(options)
export const auth = getAuth(app)
export const db = getFirestore(app, 'portal')
export const functions = getFunctions(app, 'us-west1')

if (local) {
  connectAuthEmulator(auth, `http://${local.auth}`, { disableWarnings: true })
  connectFirestoreEmulator(
    db,
    '127.0.0.1',
    Number(local.firestore.split(':')[1]),
  )
  connectFunctionsEmulator(
    functions,
    '127.0.0.1',
    Number(local.functions.split(':')[1]),
  )
}
