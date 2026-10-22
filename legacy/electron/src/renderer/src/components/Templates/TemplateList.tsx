import { useState, useEffect, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import TemplateEditor from './TemplateEditor'
import { FileText, Plus, Pencil, Trash2 } from 'lucide-react'

interface Template {
  id: string
  name: string
  content: string
  category_id: string | null
  sort_order: number
  created_at: number
  updated_at: number
}

export default function TemplateList(): React.JSX.Element {
  const { t } = useTranslation()
  const [templates, setTemplates] = useState<Template[]>([])
  const [editing, setEditing] = useState<Template | null>(null)
  const [creating, setCreating] = useState(false)

  const loadTemplates = useCallback(async () => {
    const items = await window.api.getTemplates()
    setTemplates(items)
  }, [])

  useEffect(() => {
    loadTemplates()
  }, [loadTemplates])

  const handlePaste = useCallback((template: Template) => {
    navigator.clipboard.writeText(template.content)
  }, [])

  const handleDelete = useCallback(
    async (id: string) => {
      await window.api.deleteTemplate(id)
      loadTemplates()
    },
    [loadTemplates]
  )

  if (editing || creating) {
    return (
      <TemplateEditor
        template={editing}
        onSave={() => {
          setEditing(null)
          setCreating(false)
          loadTemplates()
        }}
        onCancel={() => {
          setEditing(null)
          setCreating(false)
        }}
      />
    )
  }

  return (
    <div className="flex-1 flex flex-col select-none">
      <div className="surface-subtle flex items-center justify-between px-3.5 py-2 border-b border-border/50">
        <span className="text-xs font-medium text-muted-foreground">{t('template.title')}</span>
        <button
          onClick={() => setCreating(true)}
          className="flex items-center gap-1 rounded-md px-2 py-0.5 text-xs font-medium text-primary hover:bg-primary/10 transition-colors"
        >
          <Plus className="w-3.5 h-3.5" />
          <span>{t('template.new')}</span>
        </button>
      </div>
      <div className="flex-1 overflow-y-auto p-1.5 space-y-1">
        {templates.length === 0 ? (
          <div className="flex items-center justify-center h-full text-muted-foreground/60 text-xs">
            {t('template.empty')}
          </div>
        ) : (
          templates.map((tpl) => (
            <div
              key={tpl.id}
              onClick={() => handlePaste(tpl)}
              className="group flex items-center px-3 py-2 rounded-xl cursor-pointer hover:bg-black/[0.04] dark:hover:bg-white/[0.06] transition-colors"
            >
              <div className="mr-2.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-black/[0.04] dark:bg-white/[0.06] text-muted-foreground">
                <FileText className="h-3.5 w-3.5" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-xs font-semibold text-foreground truncate">{tpl.name}</p>
                <p className="text-[11px] text-muted-foreground/70 truncate">{tpl.content}</p>
              </div>
              <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                <button
                  onClick={(e) => {
                    e.stopPropagation()
                    setEditing(tpl)
                  }}
                  className="flex h-6 w-6 items-center justify-center rounded-md text-muted-foreground hover:bg-black/[0.06] dark:hover:bg-white/[0.1] hover:text-foreground transition-colors"
                >
                  <Pencil className="w-3 h-3" />
                </button>
                <button
                  onClick={(e) => {
                    e.stopPropagation()
                    handleDelete(tpl.id)
                  }}
                  className="flex h-6 w-6 items-center justify-center rounded-md text-destructive/80 hover:bg-destructive/15 hover:text-destructive transition-colors"
                >
                  <Trash2 className="w-3 h-3" />
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
