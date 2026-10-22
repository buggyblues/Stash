import { useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { useClipboardStore } from '../stores/clipboardStore'
import { showToast } from '../utils/toast'

export function useQueueToast(): void {
  const { t } = useTranslation()
  const { clearQueue } = useClipboardStore()

  useEffect(() => {
    const cleanups: (() => void)[] = []

    cleanups.push(
      window.api.onQueueUpdated((data) => {
        if (data.count > 0) {
          showToast(t('queue.added', { count: data.count }))
        }
      })
    )

    cleanups.push(
      window.api.onQueuePasted((data) => {
        showToast(t('queue.pasted', { index: data.index, total: data.total }))
      })
    )

    cleanups.push(
      window.api.onQueueBatchPasted((data) => {
        showToast(t('queue.batchPasted', { count: data.count }))
      })
    )

    cleanups.push(
      window.api.onQueueFinished(() => {
        showToast(t('queue.cleared'))
        clearQueue()
      })
    )

    return () => cleanups.forEach((fn) => fn())
  }, [clearQueue, t])
}
