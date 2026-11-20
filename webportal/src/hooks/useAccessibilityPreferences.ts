import { useEffect, useState } from 'react'

export type TextScale = 'default' | 'large' | 'x-large'
export type Spacing = 'default' | 'relaxed'
export type Contrast = 'default' | 'high'
export type Motion = 'system' | 'reduced'

export type AccessibilityPreferences = {
  textScale: TextScale
  lineSpacing: Spacing
  letterSpacing: Spacing
  contrast: Contrast
  motion: Motion
}

const storageKey = 'sfwa-wtl:accessibility-preferences'

const defaults: AccessibilityPreferences = {
  textScale: 'default',
  lineSpacing: 'default',
  letterSpacing: 'default',
  contrast: 'default',
  motion: 'system',
}

function readPreferences(): AccessibilityPreferences {
  try {
    const saved = window.localStorage.getItem(storageKey)
    return saved ? { ...defaults, ...(JSON.parse(saved) as Partial<AccessibilityPreferences>) } : defaults
  } catch {
    return defaults
  }
}

export function useAccessibilityPreferences() {
  const [preferences, setPreferences] = useState<AccessibilityPreferences>(readPreferences)

  useEffect(() => {
    const root = document.documentElement
    root.dataset.wtlTextScale = preferences.textScale
    root.dataset.wtlLineSpacing = preferences.lineSpacing
    root.dataset.wtlLetterSpacing = preferences.letterSpacing
    root.dataset.wtlContrast = preferences.contrast
    root.dataset.wtlMotion = preferences.motion
    try {
      window.localStorage.setItem(storageKey, JSON.stringify(preferences))
    } catch {
      // The active-session preferences still apply if browser storage is disabled.
    }
  }, [preferences])

  return {
    preferences,
    resetPreferences: () => setPreferences(defaults),
    updatePreference: <Key extends keyof AccessibilityPreferences>(key: Key, value: AccessibilityPreferences[Key]) =>
      setPreferences((current) => ({ ...current, [key]: value })),
  }
}
