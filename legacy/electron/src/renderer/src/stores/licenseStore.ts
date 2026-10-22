import { create } from 'zustand'

export type LicenseType = 'trial' | 'activated' | 'expired'

interface LicenseState {
  type: LicenseType
  trialDaysLeft: number
  activationCode: string | null
  loading: boolean

  fetchStatus: () => Promise<void>
  activate: (code: string) => Promise<{ ok: boolean; error?: string }>
  deactivate: () => Promise<void>
}

export const useLicenseStore = create<LicenseState>((set) => ({
  type: 'trial',
  trialDaysLeft: 14,
  activationCode: null,
  loading: true,

  fetchStatus: async () => {
    set({ loading: true })
    try {
      const status = await window.api.getLicenseStatus()
      set({
        type: status.type,
        trialDaysLeft: status.trialDaysLeft,
        activationCode: status.activationCode,
        loading: false,
      })
    } catch {
      set({ loading: false })
    }
  },

  activate: async (code: string) => {
    const result = await window.api.activateLicense(code)
    if (result.ok) {
      const status = await window.api.getLicenseStatus()
      set({
        type: status.type,
        trialDaysLeft: status.trialDaysLeft,
        activationCode: status.activationCode,
      })
    }
    return result
  },

  deactivate: async () => {
    await window.api.deactivateLicense()
    const status = await window.api.getLicenseStatus()
    set({
      type: status.type,
      trialDaysLeft: status.trialDaysLeft,
      activationCode: null,
    })
  },
}))
