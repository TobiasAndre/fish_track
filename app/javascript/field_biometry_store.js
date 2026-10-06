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

// Fotos das biometrias ainda não enviadas. Ficam no IndexedDB (o localStorage
// não guarda arquivos), cada uma ligada à biometria (entry_uuid). Uma foto só é
// apagada daqui quando o servidor confirma que a recebeu.
const PHOTO_DB = "fishtrack-field"
const PHOTO_STORE = "photos"

function openPhotoDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(PHOTO_DB, 1)
    request.onupgradeneeded = () => {
      const store = request.result.createObjectStore(PHOTO_STORE, { keyPath: "id" })
      store.createIndex("entry_uuid", "entry_uuid")
    }
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

async function photoTransaction(mode, work) {
  const db = await openPhotoDb()
  try {
    return await new Promise((resolve, reject) => {
      const transaction = db.transaction(PHOTO_STORE, mode)
      const result = work(transaction.objectStore(PHOTO_STORE))
      transaction.oncomplete = () => resolve(result?.result ?? result)
      transaction.onerror = () => reject(transaction.error)
      transaction.onabort = () => reject(transaction.error)
    })
  } finally {
    db.close()
  }
}

export const fieldPhotoStore = {
  // photo: { id, entry_uuid, blob, name, type, size, created_at }
  put: (photo) => photoTransaction("readwrite", (store) => store.put(photo)),
  forEntry: (entryUuid) => photoTransaction("readonly", (store) => store.index("entry_uuid").getAll(entryUuid)),
  delete: (id) => photoTransaction("readwrite", (store) => store.delete(id)),
  deleteForEntry: async (entryUuid) => {
    const photos = await fieldPhotoStore.forEntry(entryUuid)
    await Promise.all(photos.map((photo) => fieldPhotoStore.delete(photo.id)))
  }
}
