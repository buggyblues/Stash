import { useState, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { Button } from '../ui/button'

interface Template {
  id: string
  name: string
  content: string
}

interface Props {
  template: Template | null
  onSave: () => void
  onCancel: () => void
}

export default function TemplateEditor({ template, onSave, onCancel }: Props): React.JSX.Element {
  const { t } = useTranslation()
  const [name, setName] = useState(template?.name || '')
  const [content, setContent] = useState(template?.content || '')

  const handleSave = useCallback(async () => {
    if (!name.trim() || !content.trim()) return
    if (template) {
      await window.api.updateTemplate(template.id, name, content)
    } else {
      const id = crypto.randomUUID().replace(/-/g, '').slice(0, 21)
      await window.api.createTemplate(id, name, content)
    }
    onSave()
  }, [name, content, template, onSave])

  return (
    <div className="flex-1 flex flex-col p-4 gap-3 bg-card/40 backdrop-blur-md select-none">
      <div className="flex items-center justify-between">
        <span className="text-xs font-semibold text-foreground">{template ? t('template.edit') : t('template.create')}</span>
        <button onClick={onCancel} className="text-xs text-muted-foreground hover:text-foreground transition-colors">
          {t('common.cancel')}
        </button>
      </div>
      <input
        type="text"
        value={name}
        onChange={(e) => setName(e.target.value)}
        placeholder={t('template.namePlaceholder')}
        className="w-full bg-black/[0.03] dark:bg-white/[0.06] border border-border/70 rounded-lg px-2.5 py-1.5 text-xs text-foreground placeholder:text-muted-foreground/60 outline-none focus-visible:ring-2 focus-visible:ring-primary/25 focus-visible:border-primary/80 transition-all"
      />
      <textarea
        value={content}
        onChange={(e) => setContent(e.target.value)}
        placeholder={t('template.contentPlaceholder')}
        className="flex-1 w-full bg-black/[0.03] dark:bg-white/[0.06] border border-border/70 rounded-lg p-2.5 text-xs text-foreground placeholder:text-muted-foreground/60 outline-none focus-visible:ring-2 focus-visible:ring-primary/25 focus-visible:border-primary/80 resize-none font-mono leading-relaxed transition-all"
      />
      <Button
        onClick={handleSave}
        disabled={!name.trim() || !content.trim()}
        size="sm"
        className="w-full"
      >
        {t('common.save')}
      </Button>
    </div>
  )
}
