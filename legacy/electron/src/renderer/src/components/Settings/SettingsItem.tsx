interface SettingsItemProps {
  label: string
  description?: string
  children: React.ReactNode
}

export default function SettingsItem({
  label,
  description,
  children
}: SettingsItemProps): React.JSX.Element {
  return (
    <div className="flex items-center justify-between py-3">
      <div className="flex-1 min-w-0 mr-4">
        <p className="text-sm text-foreground">{label}</p>
        {description && (
          <p className="text-xs text-muted-foreground mt-0.5">{description}</p>
        )}
      </div>
      <div className="shrink-0">{children}</div>
    </div>
  )
}

export function SettingsToggle({
  value,
  onChange
}: {
  value: boolean
  onChange: (v: boolean) => void
}): React.JSX.Element {
  return (
    <button
      onClick={() => onChange(!value)}
      className={`relative w-10 h-6 rounded-full transition-colors ${
        value ? 'bg-primary' : 'bg-muted'
      }`}
    >
      <span
        className={`absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform ${
          value ? 'translate-x-4' : 'translate-x-0'
        }`}
      />
    </button>
  )
}

export function SettingsSelect<T extends string | number>({
  value,
  options,
  onChange
}: {
  value: T
  options: { label: string; value: T }[]
  onChange: (v: T) => void
}): React.JSX.Element {
  return (
    <select
      value={value}
      onChange={(e) => {
        const raw = e.target.value
        const parsed = typeof value === 'number' ? (Number(raw) as T) : (raw as T)
        onChange(parsed)
      }}
      className="bg-muted text-foreground text-xs px-2 py-1.5 rounded-md border border-border outline-none"
    >
      {options.map((opt) => (
        <option key={String(opt.value)} value={opt.value}>
          {opt.label}
        </option>
      ))}
    </select>
  )
}
