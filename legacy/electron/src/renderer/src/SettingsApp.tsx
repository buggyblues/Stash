import { useState } from 'react'
import { useEffect } from 'react'
import SettingsPage from './components/Settings/SettingsPage'
import OnboardingPage from './components/Onboarding/OnboardingPage'
import { useSettingsStore } from './stores/settingsStore'
import { isThemeMode } from '../../shared/theme'

function SettingsApp(): React.JSX.Element {
  const resolvedTheme = useSettingsStore((s) => s.resolvedTheme)
  const [view] = useState<'settings' | 'onboarding'>(() => {
    const params = new URLSearchParams(window.location.search)
    return params.get('view') === 'onboarding' ? 'onboarding' : 'settings'
  })

  const handleClose = (): void => {
    window.close()
  }

  useEffect(() => {
    const unsubLayout = window.api.onLayoutModeChanged((mode) => {
      if (mode === 'center' || mode === 'side' || mode === 'bottom') {
        useSettingsStore.setState({ layoutMode: mode })
      }
    })
    const unsubTheme = window.api.onThemeChanged((theme) => {
      if (!isThemeMode(theme)) return
      useSettingsStore.getState().syncTheme(theme)
    })
    const unsubAccentColor = window.api.onAccentColorChanged((color) => {
      useSettingsStore.getState().syncAccentColor(color)
    })

    return () => {
      unsubLayout()
      unsubTheme()
      unsubAccentColor()
    }
  }, [])

  return (
    <div className={`w-full h-screen ${resolvedTheme}`}>
      {view === 'onboarding' ? (
        <OnboardingPage onComplete={handleClose} isRevisit />
      ) : (
        <SettingsPage onClose={handleClose} />
      )}
    </div>
  )
}

export default SettingsApp
