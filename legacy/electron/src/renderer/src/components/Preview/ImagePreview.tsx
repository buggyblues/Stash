import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'

interface Props {
  content: string
  metadata: string | null
}

export default function ImagePreview({ content, metadata }: Props): React.JSX.Element {
  const { t } = useTranslation()
  const size = useMemo(() => {
    if (!metadata) return null
    try {
      const parsed = JSON.parse(metadata)
      return { width: parsed.width, height: parsed.height }
    } catch {
      return null
    }
  }, [metadata])

  const isFilePath = content.startsWith('/') || content.startsWith('~')

  const src = useMemo(() => {
    if (isFilePath) {
      return `file://${content}`
    }
    return `data:image/png;base64,${content}`
  }, [content, isFilePath])

  return (
    <div className="flex flex-col items-center gap-3 p-4 select-none">
      <img
        src={src}
        alt={t('preview.image.alt')}
        className="max-w-full max-h-64 rounded-xl border border-black/10 dark:border-white/15 object-contain shadow-md"
      />
      {size && (
        <span className="text-[11px] font-mono text-muted-foreground/80 bg-black/[0.04] dark:bg-white/[0.06] px-2 py-0.5 rounded-md">
          {size.width} × {size.height}
          {isFilePath && ` ${t('preview.fileReference')}`}
        </span>
      )}
    </div>
  )
}
