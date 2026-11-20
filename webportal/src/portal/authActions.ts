import {
  EmailAuthProvider,
  GoogleAuthProvider,
  reauthenticateWithCredential,
  reauthenticateWithPopup,
  type User,
} from 'firebase/auth'

export function errorMessage(error: unknown) {
  const code =
    typeof error === 'object' && error !== null && 'code' in error
      ? error.code
      : ''
  const known: Record<string, string> = {
    'auth/invalid-credential': 'Check your email and password, then try again.',
    'auth/email-already-in-use':
      'This email already has an account. Sign in or reset your password.',
    'auth/popup-closed-by-user':
      'The sign-in window was closed. Try again when you are ready.',
    'auth/popup-blocked':
      'Allow the Google sign-in window in your browser and try again.',
    'auth/expired-action-code': 'This link has expired. Request a new one.',
    'auth/invalid-action-code':
      'This link has already been used or is invalid.',
    'auth/requires-recent-login':
      'Confirm your current sign-in before making this change.',
    'auth/network-request-failed':
      'The authentication service could not be reached. Check your connection.',
  }
  return (
    known[String(code)] ??
    (error instanceof Error
      ? error.message
      : 'The request could not be completed.')
  )
}

export async function confirmIdentity(user: User, password: string) {
  if (
    user.providerData.some((provider) => provider.providerId === 'password') &&
    user.email
  ) {
    await reauthenticateWithCredential(
      user,
      EmailAuthProvider.credential(user.email, password),
    )
  } else {
    await reauthenticateWithPopup(user, new GoogleAuthProvider())
  }
  await user.getIdToken(true)
}
