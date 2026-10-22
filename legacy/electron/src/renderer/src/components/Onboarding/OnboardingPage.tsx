import { useState, useCallback, useEffect } from 'react'
import { motion } from 'framer-motion'
import { useTranslation } from 'react-i18next'
import { useSettingsStore } from '../../stores/settingsStore'
import { useShallow } from 'zustand/react/shallow'
import { cn } from '../../lib/utils'
import { Button } from '../ui/button'
import { Switch } from '../ui/switch'
import { AppLogo } from '../ui/app-logo'
import {
  Rocket,
  Keyboard,
  Lock,
  Sparkles,
  Zap,
  Clipboard,
  Code2,
  Tag,
  FileText,
  Layers,
  Wand2,
  Eye,
} from 'lucide-react'

interface Step {
  title: string
  description: string
  icon: React.ElementType
  content: React.ReactNode
}

interface Props {
  onComplete: () => void
  isRevisit?: boolean
}

export default function OnboardingPage({ onComplete, isRevisit }: Props): React.JSX.Element {
  const { t } = useTranslation()
  const [currentStep, setCurrentStep] = useState(0)
  const [viewportSize, setViewportSize] = useState(() => getViewportSize())
  const { setICloudSync, setHasCompletedOnboarding } = useSettingsStore(
    useShallow((state) => ({
      setICloudSync: state.setICloudSync,
      setHasCompletedOnboarding: state.setHasCompletedOnboarding,
    }))
  )
  const [syncChoice, setSyncChoice] = useState(false)

  useEffect(() => {
    const handleResize = (): void => {
      setViewportSize(getViewportSize())
    }

    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  const steps: Step[] = [
    {
      title: t('onboarding.step1.title'),
      description: t('onboarding.step1.description'),
      icon: Rocket,
      content: (
        <div className="space-y-4">
          <Feature
            icon={Clipboard}
            title={t('onboarding.step1.feature1.title')}
            desc={t('onboarding.step1.feature1.desc')}
          />
          <Feature
            icon={Zap}
            title={t('onboarding.step1.feature2.title')}
            desc={t('onboarding.step1.feature2.desc')}
          />
        </div>
      ),
    },
    {
      title: t('onboarding.step2.title'),
      description: t('onboarding.step2.description'),
      icon: Sparkles,
      content: (
        <div className="space-y-4">
          <Feature
            icon={Layers}
            title={t('onboarding.step2.feature1.title')}
            desc={t('onboarding.step2.feature1.desc')}
          />
          <Feature
            icon={Code2}
            title={t('onboarding.step2.feature2.title')}
            desc={t('onboarding.step2.feature2.desc')}
          />
          <Feature
            icon={Eye}
            title={t('onboarding.step2.feature3.title')}
            desc={t('onboarding.step2.feature3.desc')}
          />
          <Feature
            icon={Wand2}
            title={t('onboarding.step2.feature4.title')}
            desc={t('onboarding.step2.feature4.desc')}
          />
        </div>
      ),
    },
    {
      title: t('onboarding.step3.title'),
      description: t('onboarding.step3.description'),
      icon: Zap,
      content: (
        <div className="space-y-4">
          <Feature
            icon={FileText}
            title={t('onboarding.step3.feature1.title')}
            desc={t('onboarding.step3.feature1.desc')}
          />
          <Feature
            icon={Tag}
            title={t('onboarding.step3.feature2.title')}
            desc={t('onboarding.step3.feature2.desc')}
          />
          <Feature
            icon={Sparkles}
            title={t('onboarding.step3.feature3.title')}
            desc={t('onboarding.step3.feature3.desc')}
          />
          <Feature
            icon={Layers}
            title={t('onboarding.step3.feature4.title')}
            desc={t('onboarding.step3.feature4.desc')}
          />
        </div>
      ),
    },
    {
      title: t('onboarding.step5.title'),
      description: t('onboarding.step5.description'),
      icon: Keyboard,
      content: (
        <div className="flex flex-col items-center gap-4">
          <div className="flex flex-wrap items-center justify-center gap-2">
            <KeyCap label="⇧" />
            <span className="text-muted-foreground">+</span>
            <KeyCap label="⌘" />
            <span className="text-muted-foreground">+</span>
            <KeyCap label="V" />
          </div>
          <p className="text-center text-xs leading-6 text-muted-foreground">
            {t('onboarding.step5.shortcutHint')}
            <br />
            {t('onboarding.step5.autoPaste')}
          </p>
          <div className="w-full rounded-[1.25rem] border border-border/60 bg-card p-4 shadow-sm">
            <p className="mb-2 text-[10px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
              {t('onboarding.step5.moreShortcuts')}
            </p>
            <div className="space-y-2 text-xs text-foreground/80">
              <ShortcutRow
                title={t('onboarding.step5.seqPaste')}
                desc={t('onboarding.step5.seqPasteDesc')}
              />
              <ShortcutRow
                title={t('onboarding.step5.batchPaste')}
                desc={t('onboarding.step5.batchPasteDesc')}
              />
              <ShortcutRow
                title={t('onboarding.step5.numbers')}
                desc={t('onboarding.step5.numbersDesc')}
              />
              <ShortcutRow
                title={t('onboarding.step5.widget')}
                desc={t('onboarding.step5.widgetDesc')}
              />
              <ShortcutRow
                title={t('onboarding.step5.layout')}
                desc={t('onboarding.step5.layoutDesc')}
              />
              <ShortcutRow
                title={t('onboarding.step5.closePanel')}
                desc={t('onboarding.step5.closePanelDesc')}
              />
            </div>
          </div>
        </div>
      ),
    },
    {
      title: t('onboarding.step6.title'),
      description: t('onboarding.step6.description'),
      icon: Lock,
      content: (
        <div className="space-y-4">
          <div className="rounded-[1.25rem] border border-border/60 bg-card p-4 shadow-sm">
            <p className="mb-2 text-xs font-semibold text-foreground">
              {t('onboarding.step6.storage.title')}
            </p>
            <p className="text-[11px] leading-6 text-muted-foreground">
              {t('onboarding.step6.storage.desc')}
            </p>
          </div>
          <div className="rounded-[1.25rem] border border-border/60 bg-card p-4 shadow-sm">
            <div className="mb-2 flex items-center justify-between gap-3">
              <p className="text-xs font-semibold text-foreground">
                {t('onboarding.step6.sync.title')}
              </p>
              <Switch
                checked={syncChoice}
                onCheckedChange={setSyncChoice}
                aria-label={t('onboarding.step6.sync.title')}
              />
            </div>
            <p className="text-[11px] leading-6 text-muted-foreground">
              {t('onboarding.step6.sync.desc')}
            </p>
          </div>
        </div>
      ),
    },
    {
      title: t('onboarding.step7.title'),
      description: t('onboarding.step7.description'),
      icon: Sparkles,
      content: (
        <div className="flex flex-col items-center gap-5">
          <AppLogo size="lg" />
          <p className="text-center text-xs leading-6 text-muted-foreground">
            {t('onboarding.step7.ready')}
            <br />
            {t('onboarding.step7.freeInfo')}
          </p>
        </div>
      ),
    },
  ]

  const isLastStep = currentStep === steps.length - 1

  const handleNext = useCallback(() => {
    if (isLastStep) {
      if (!isRevisit) {
        setICloudSync(syncChoice)
        setHasCompletedOnboarding(true)
      }
      onComplete()
    } else {
      setCurrentStep((s) => s + 1)
    }
  }, [isLastStep, isRevisit, syncChoice, setICloudSync, setHasCompletedOnboarding, onComplete])

  const handleSkip = useCallback(() => {
    if (!isRevisit) {
      setHasCompletedOnboarding(true)
    }
    onComplete()
  }, [isRevisit, setHasCompletedOnboarding, onComplete])

  const step = steps[currentStep]
  const showSidebar = viewportSize.width >= 768 && viewportSize.height >= 560

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.98, y: 14 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      transition={{ duration: 0.25, ease: 'easeOut' }}
      className="surface-panel hairline relative flex h-full w-full flex-col overflow-hidden rounded-[1.25rem] border border-border/70 select-none shadow-2xl"
    >
      <div className="pointer-events-none absolute inset-x-0 top-0 h-48 bg-[radial-gradient(circle_at_top,_rgba(255,127,67,0.12),_transparent_60%)]" />
      <div className="relative flex min-h-0 flex-1 flex-col px-5 py-4 sm:px-6 sm:py-5 md:px-8 md:py-6">
        <div className="mb-4 flex shrink-0 items-start justify-between gap-4 md:mb-5">
          <div className="min-w-0">
            <p className="text-[10px] font-semibold uppercase tracking-[0.22em] text-muted-foreground/80">
              Stash
            </p>
            <div className="mt-2 flex items-start gap-3">
              {!showSidebar && (
                <div className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary shadow-xs">
                  <step.icon className="h-4.5 w-4.5" />
                </div>
              )}
              <div className="min-w-0">
                <p
                  data-display="true"
                  className="text-lg font-semibold leading-tight text-balance text-foreground sm:text-xl md:text-2xl tracking-tight"
                >
                  {step.title}
                </p>
                <p className="mt-1.5 max-w-2xl text-xs leading-relaxed text-muted-foreground sm:text-sm">
                  {step.description}
                </p>
              </div>
            </div>
          </div>
          <div className="shrink-0 rounded-full border border-border/60 bg-card/60 backdrop-blur-md px-2.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
            {currentStep + 1} / {steps.length}
          </div>
        </div>

        <div
          className={cn(
            'grid min-h-0 flex-1 gap-4 md:gap-6',
            showSidebar && 'md:grid-cols-[160px_minmax(0,1fr)]'
          )}
        >
          {showSidebar && (
            <div className="hidden min-h-0 flex-col justify-between rounded-2xl border border-border/50 bg-card/50 backdrop-blur-md p-3.5 shadow-xs md:flex">
              <div>
                <div className="mb-3 inline-flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary shadow-xs">
                  <step.icon className="w-5 h-5" />
                </div>
                <div className="space-y-1">
                  {steps.map((candidate, index) => (
                    <div
                      key={candidate.title}
                      className={cn(
                        'rounded-lg px-2.5 py-1.5 text-xs font-medium transition-all duration-150',
                        index === currentStep
                          ? 'bg-primary text-primary-foreground shadow-[inset_0_1px_0_rgba(255,255,255,0.3),0_1px_2px_rgba(0,0,0,0.12)]'
                          : index < currentStep
                            ? 'bg-black/[0.04] dark:bg-white/[0.06] text-foreground/80'
                            : 'text-muted-foreground/70'
                      )}
                    >
                      {candidate.title}
                    </div>
                  ))}
                </div>
              </div>
              <p className="text-[10px] leading-relaxed text-muted-foreground/75 px-1">
                {t('onboarding.step7.hint')}
              </p>
            </div>
          )}

          <div className="flex min-h-0 flex-col rounded-2xl border border-border/50 bg-card/50 backdrop-blur-md shadow-xs md:rounded-2xl overflow-hidden">
            <div className="flex min-h-0 flex-1 flex-col">
              <div className="min-h-0 flex-1 overflow-y-auto px-4 py-4 sm:px-5 sm:py-5 md:px-6 md:py-6">
                <div className="w-full">{step.content}</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="relative flex shrink-0 items-center justify-between border-t border-border/60 px-5 py-3 sm:px-6 sm:py-4 md:px-8">
        <div className="flex items-center gap-2">
          {steps.map((_, i) => (
            <div
              key={i}
              className={`h-2 w-2 rounded-full transition-colors ${
                i === currentStep ? 'bg-primary' : i < currentStep ? 'bg-primary/40' : 'bg-border'
              }`}
            />
          ))}
        </div>

        <div className="flex items-center gap-3">
          {!isLastStep && (
            <Button
              onClick={handleSkip}
              variant="ghost"
              size="sm"
              className="text-xs text-muted-foreground hover:text-foreground"
            >
              {t('onboarding.skip')}
            </Button>
          )}
          <Button onClick={handleNext} size="sm" className="px-4 text-xs">
            {isLastStep ? t('onboarding.start') : t('onboarding.next')}
          </Button>
        </div>
      </div>
    </motion.div>
  )
}

function Feature({
  icon: Icon,
  title,
  desc,
}: {
  icon: React.ElementType
  title: string
  desc: string
}): React.JSX.Element {
  return (
    <div className="flex items-start gap-3 rounded-xl border border-border/50 bg-card/60 backdrop-blur-md px-3.5 py-2.5 shadow-2xs sm:px-4">
      <Icon className="w-4 h-4 mt-0.5 text-primary shrink-0" />
      <div>
        <p className="text-xs font-semibold text-foreground">{title}</p>
        <p className="text-[11px] leading-relaxed text-muted-foreground">{desc}</p>
      </div>
    </div>
  )
}

function KeyCap({ label }: { label: string }): React.JSX.Element {
  return (
    <span className="inline-flex h-8 w-8 items-center justify-center rounded-lg border border-black/10 dark:border-white/15 bg-card/90 dark:bg-card/60 text-xs font-mono font-semibold text-foreground shadow-[inset_0_1px_0_rgba(255,255,255,0.8),0_1.5px_3px_rgba(0,0,0,0.08)] sm:h-9 sm:w-9 sm:text-xs">
      {label}
    </span>
  )
}

function ShortcutRow({ title, desc }: { title: string; desc: string }): React.JSX.Element {
  return (
    <div className="flex flex-col gap-0.5 sm:flex-row sm:items-center sm:justify-between sm:gap-3">
      <span>{title}</span>
      <span className="text-muted-foreground sm:text-right">{desc}</span>
    </div>
  )
}

function getViewportSize(): { width: number; height: number } {
  return {
    width: window.innerWidth,
    height: window.innerHeight,
  }
}
