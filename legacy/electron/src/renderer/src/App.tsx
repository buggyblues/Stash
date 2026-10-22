import { useEffect, useRef, useState } from 'react'
import PanelWindow from './components/Panel/PanelWindow'
import OnboardingPage from './components/Onboarding/OnboardingPage'
import { useClipboardStore } from './stores/clipboardStore'
import { useSettingsStore } from './stores/settingsStore'
import { isThemeMode } from '../../shared/theme'

function App(): React.JSX.Element {
  const { loadItems, addItem, setVisible } = useClipboardStore()
  const resolvedTheme = useSettingsStore((s) => s.resolvedTheme)
  const hasCompletedOnboarding = useSettingsStore((s) => s.hasCompletedOnboarding)
  const [showOnboarding, setShowOnboarding] = useState(!hasCompletedOnboarding)
  const hasNewItemRef = useRef(false)

  useEffect(() => {
    loadItems()

    const unsubNewItem = window.api.onNewItem((item) => {
      addItem(item)
      hasNewItemRef.current = true
    })

    const unsubShown = window.api.onPanelShown(() => {
      setVisible(true)
      if (hasNewItemRef.current) {
        loadItems()
        hasNewItemRef.current = false
      }
    })

    const unsubHidden = window.api.onPanelHidden(() => {
      setVisible(false)
    })

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
      unsubNewItem()
      unsubShown()
      unsubHidden()
      unsubLayout()
      unsubTheme()
      unsubAccentColor()
    }
  }, [])

  return (
    <div className={`w-full h-screen ${resolvedTheme}`}>
      {showOnboarding ? (
        <OnboardingPage onComplete={() => setShowOnboarding(false)} />
      ) : (
        <PanelWindow />
      )}
    </div>
  )
}

export default App
