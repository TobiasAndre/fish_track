// Registra o service worker (instalação como app e página offline).
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker").catch((error) => {
      console.warn("Service worker não registrado:", error)
    })
  })
}
