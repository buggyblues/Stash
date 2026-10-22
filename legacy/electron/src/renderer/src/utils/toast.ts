type ToastOptions = {
  document?: Pick<Document, 'body' | 'createElement' | 'getElementById'>
  setTimeout?: typeof globalThis.setTimeout
  clearTimeout?: typeof globalThis.clearTimeout
  duration?: number
  fadeDuration?: number
}

const TOAST_ID = 'zpaste-toast'
const TOAST_CLASS_NAME =
  'fixed bottom-4 left-1/2 -translate-x-1/2 px-4 py-2 rounded-lg bg-foreground/90 text-background text-sm font-medium shadow-lg z-[9999] transition-opacity duration-200'

let toastTimer: ReturnType<typeof setTimeout> | null = null

export function showToast(message: string, options: ToastOptions = {}): void {
  const documentRef = options.document ?? document
  const setTimeoutRef = options.setTimeout ?? globalThis.setTimeout
  const clearTimeoutRef = options.clearTimeout ?? globalThis.clearTimeout
  const duration = options.duration ?? 2000
  const fadeDuration = options.fadeDuration ?? 200

  let el = documentRef.getElementById(TOAST_ID)
  if (!el) {
    el = documentRef.createElement('div')
    el.id = TOAST_ID
    el.className = TOAST_CLASS_NAME
    documentRef.body.appendChild(el)
  }

  el.textContent = message
  el.style.opacity = '1'

  if (toastTimer) clearTimeoutRef(toastTimer)
  toastTimer = setTimeoutRef(() => {
    el!.style.opacity = '0'
    setTimeoutRef(() => el?.remove(), fadeDuration)
    toastTimer = null
  }, duration)
}
