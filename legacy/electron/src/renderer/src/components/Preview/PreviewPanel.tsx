import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ClipboardItem } from '../../stores/clipboardStore'
import CodePreview from './CodePreview'
import JsonPreview from './JsonPreview'
import ColorPreview from './ColorPreview'
import ImagePreview from './ImagePreview'
import { decodeBase64, decodeURL } from '../../utils/formatters'
import {
  toUpperCase,
  toLowerCase,
  toTitleCase,
  toCamelCase,
  toSnakeCase,
  toKebabCase,
  trimWhitespace,
  removeAllWhitespace
} from '../../utils/transformers'
import { Clipboard, Copy, Link, Code, PanelRightClose } from 'lucide-react'
import { Button } from '../ui/button'
import { useClipboardStore } from '../../stores/clipboardStore'
import { useClipboardItemContent } from '../../hooks/useClipboardItemContent'
import { getContentTypeLabel } from '../../utils/contentType'

interface Props {
  item: ClipboardItem | null
  layout?: 'side' | 'bottom'
}

export default function PreviewPanel({ item, layout = 'side' }: Props): React.JSX.Element {
  const { t } = useTranslation()
  const { togglePreview } = useClipboardStore()
  const content = useClipboardItemContent(item?.id ?? '', item?.content ?? '', !!item)
  const resolvedItem = item && content !== item.content ? { ...item, content } : item

  if (!resolvedItem) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center px-6 text-muted-foreground select-none">
        <div className="rounded-2xl border border-border/50 bg-card/60 backdrop-blur-md px-8 py-10 text-center shadow-xs">
          <Clipboard className="mx-auto mb-3 h-10 w-10 opacity-20" />
          <p className="text-xs font-medium text-muted-foreground">{t('preview.selectItem')}</p>
        </div>
      </div>
    )
  }

  return (
    <div className={`surface-subtle flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden select-none ${layout === 'side' ? 'border-l border-border/50' : ''}`}>
      <div className="flex shrink-0 items-center justify-between border-b border-border/50 px-3.5 py-2">
        <div className="flex min-w-0 items-center gap-2">
          <span className="shrink-0 rounded-full bg-primary/15 text-foreground px-2 py-0.5 text-[9px] font-semibold tracking-wider uppercase">
            {getContentTypeLabel(t, resolvedItem.content_type)}
          </span>
          {resolvedItem.title && (
            <span className="truncate text-xs font-semibold text-primary">
              {resolvedItem.title}
            </span>
          )}
        </div>
        <div className="flex items-center gap-2 text-[10px] text-muted-foreground/80">
          {resolvedItem.use_count > 0 && (
            <span className="tabular-nums">
              {t('preview.useCount', { count: resolvedItem.use_count })}
            </span>
          )}
          <span className="tabular-nums">
            {new Date(resolvedItem.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
          </span>
          <button
            onClick={togglePreview}
            aria-label={t('preview.collapseDetails')}
            className="flex h-6 w-6 items-center justify-center rounded-md text-muted-foreground hover:bg-black/[0.05] dark:hover:bg-white/[0.08] hover:text-foreground transition-all duration-150 active:scale-90"
            title={`${t('preview.collapseDetails')} (⌥)`}
          >
            <PanelRightClose className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      <div className="min-h-0 flex-1 overflow-auto">
        <PreviewContent item={resolvedItem} />
      </div>

      {resolvedItem.content_type === 'text' && <TextToolbar content={resolvedItem.content} />}
      {resolvedItem.content_type === 'base64' && <Base64Toolbar content={resolvedItem.content} />}
      {resolvedItem.content_type === 'url' && <UrlToolbar content={resolvedItem.content} />}
    </div>
  )
}

function PreviewContent({ item }: { item: ClipboardItem }): React.JSX.Element {
  const metadata = useMemo(() => {
    if (!item.metadata) return {}
    try {
      return JSON.parse(item.metadata)
    } catch {
      return {}
    }
  }, [item.metadata])

  switch (item.content_type) {
    case 'code':
      return <CodePreview code={item.content} language={metadata.language || 'plaintext'} />
    case 'json':
      return <JsonPreview content={item.content} />
    case 'color':
      return <ColorPreview content={item.content} />
    case 'image':
      return <ImagePreview content={item.content} metadata={item.metadata} />
    default:
      return (
        <pre className="whitespace-pre-wrap break-all p-4 font-mono text-xs leading-relaxed text-foreground select-text">
          {item.content}
        </pre>
      )
  }
}

function TextToolbar({ content }: { content: string }): React.JSX.Element {
  const { t } = useTranslation()
  const tools = [
    { label: t('preview.toolbar.upper'), fn: () => toUpperCase(content) },
    { label: t('preview.toolbar.lower'), fn: () => toLowerCase(content) },
    { label: t('preview.toolbar.title'), fn: () => toTitleCase(content) },
    { label: t('preview.toolbar.camel'), fn: () => toCamelCase(content) },
    { label: t('preview.toolbar.snake'), fn: () => toSnakeCase(content) },
    { label: t('preview.toolbar.kebab'), fn: () => toKebabCase(content) },
    { label: t('preview.toolbar.trim'), fn: () => trimWhitespace(content) },
    { label: t('preview.toolbar.noSpace'), fn: () => removeAllWhitespace(content) }
  ]

  return (
    <div className="flex shrink-0 flex-wrap gap-1.5 border-t border-border/50 bg-black/[0.02] dark:bg-white/[0.03] px-3 py-2">
      {tools.map(({ label, fn }) => (
        <button
          key={label}
          onClick={() => navigator.clipboard.writeText(fn())}
          className="h-6 px-2 rounded-md border border-black/[0.06] dark:border-white/[0.08] bg-background/80 hover:bg-background text-foreground text-[10px] font-medium transition-all duration-150 active:scale-95 shadow-2xs"
        >
          {label}
        </button>
      ))}
    </div>
  )
}

function Base64Toolbar({ content }: { content: string }): React.JSX.Element {
  const { t } = useTranslation()
  const [expanded, setExpanded] = useState(false)

  const decoded = useMemo(() => {
    if (!expanded) return null
    return decodeBase64(content)
  }, [expanded, content])

  return (
    <div className="shrink-0 border-t border-border/50 bg-black/[0.02] dark:bg-white/[0.03]">
      <div className="px-3 py-2">
        <div className="flex items-center justify-between">
          <button
            onClick={() => setExpanded((v) => !v)}
            className="flex items-center gap-1.5 text-[11px] font-medium text-primary hover:underline"
          >
            <Code className="w-3.5 h-3.5" />
            <span>{expanded ? t('preview.collapseDecoded') : t('preview.expandDecoded')}</span>
          </button>
          {expanded && decoded?.valid && (
            <Button
              variant="ghost"
              size="sm"
              className="h-6 px-2 text-[10px]"
              onClick={() => navigator.clipboard.writeText(decoded.decoded)}
            >
              <Copy className="w-3 h-3 mr-1" /> {t('preview.copy')}
            </Button>
          )}
        </div>
        {expanded && decoded && (
          <pre className="mt-2 max-h-24 overflow-auto whitespace-pre-wrap break-all rounded-lg border border-border/50 bg-black/[0.04] dark:bg-white/[0.06] p-2.5 font-mono text-xs text-foreground select-text">
            {decoded.valid ? decoded.decoded : t('preview.invalidBase64')}
          </pre>
        )}
      </div>
    </div>
  )
}

function UrlToolbar({ content }: { content: string }): React.JSX.Element {
  const { t } = useTranslation()
  const decoded = decodeURL(content)
  const showDecoded = decoded !== content

  return (
    <div className="flex shrink-0 flex-wrap gap-1.5 border-t border-border/50 bg-black/[0.02] dark:bg-white/[0.03] px-3 py-2">
      <button
        onClick={() => navigator.clipboard.writeText(content)}
        className="inline-flex items-center gap-1 h-6 px-2 rounded-md border border-black/[0.06] dark:border-white/[0.08] bg-background/80 hover:bg-background text-foreground text-[10px] font-medium transition-all duration-150 active:scale-95 shadow-2xs"
      >
        <Link className="w-3 h-3 text-muted-foreground" />
        <span>{t('preview.copyUrl')}</span>
      </button>
      {showDecoded && (
        <button
          onClick={() => navigator.clipboard.writeText(decoded)}
          className="inline-flex items-center gap-1 h-6 px-2 rounded-md border border-black/[0.06] dark:border-white/[0.08] bg-background/80 hover:bg-background text-foreground text-[10px] font-medium transition-all duration-150 active:scale-95 shadow-2xs"
        >
          <Code className="w-3 h-3 text-muted-foreground" />
          <span>{t('preview.copyDecoded')}</span>
        </button>
      )}
    </div>
  )
}
