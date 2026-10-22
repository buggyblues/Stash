import { useState, useCallback, useEffect, useRef } from 'react'
import { useTranslation } from 'react-i18next'
import { Check, X, Edit2 } from 'lucide-react'
import { Button } from '../ui/button'

interface Props {
  content: string
  onSave: (content: string) => void
  onCancel: () => void
}

export default function QuickEdit({ content, onSave, onCancel }: Props): React.JSX.Element {
  const { t } = useTranslation()
  const [text, setText] = useState(content)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  useEffect(() => {
    textareaRef.current?.focus()
    textareaRef.current?.select()
  }, [])

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        onSave(text)
      } else if (e.key === 'Escape') {
        e.preventDefault()
        onCancel()
      }
    },
    [text, onSave, onCancel]
  )

  return (
    <div className="flex flex-col h-full border-l border-border/50 bg-card/60 backdrop-blur-md">
      <div className="surface-subtle flex items-center justify-between px-3 py-2 border-b border-border/50">
        <div className="flex items-center gap-1.5 text-muted-foreground">
          <Edit2 className="w-3.5 h-3.5" />
          <span className="text-xs font-medium">{t('panel.quickEdit.title')}</span>
        </div>
        <div className="flex items-center gap-1.5">
          <Button
            variant="ghost"
            size="sm"
            className="h-6 px-2 text-[11px]"
            onClick={onCancel}
          >
            <X className="w-3 h-3 mr-1" />
            {t('common.cancel')}
          </Button>
          <Button
            size="sm"
            className="h-6 px-2.5 text-[11px]"
            onClick={() => onSave(text)}
          >
            <Check className="w-3 h-3 mr-1" />
            {t('common.save')}
          </Button>
        </div>
      </div>
      <textarea
        ref={textareaRef}
        value={text}
        onChange={(e) => setText(e.target.value)}
        onKeyDown={handleKeyDown}
        className="flex-1 w-full bg-transparent p-3.5 text-xs outline-none resize-none font-mono leading-relaxed placeholder:text-muted-foreground/60 text-foreground"
        spellCheck={false}
      />
    </div>
  )
}
