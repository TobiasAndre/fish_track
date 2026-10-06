// Armazenamento no aparelho da biometria em campo (offline).
//
//   reference: tanques dos lotes ativos baixados do servidor (empresa, usuário,
//              saldo e última biometria de cada tanque). Apagado no logout.
//   queue:     biometrias lançadas e ainda não enviadas. Ficam até o servidor
//              confirmar o recebimento, mesmo após logout, para nada se perder.
//   sent:      as últimas biometrias enviadas (só para conferência na tela).
const KEYS = {
  reference: "fishtrack:field-biometry:reference",
  queue: "fishtrack:field-biometry:queue",
  sent: "fishtrack:field-biometry:sent"
}

function read(key, fallback) {
  try {
    const raw = localStorage.getItem(key)
    return raw ? JSON.parse(raw) : fallback
  } catch {
    return fallback
  }
}

function write(key, value) {
  localStorage.setItem(key, JSON.stringify(value))
}

export const fieldBiometryStore = {
  reference: () => read(KEYS.reference, null),
  saveReference: (reference) => write(KEYS.reference, reference),
  clearReference: () => {
    try { localStorage.removeItem(KEYS.reference) } catch {}
  },

  queue: () => read(KEYS.queue, []),
  saveQueue: (queue) => write(KEYS.queue, queue),

  sent: () => read(KEYS.sent, []),
  addSent: (entries) => write(KEYS.sent, [...entries, ...read(KEYS.sent, [])].slice(0, 20))
}
