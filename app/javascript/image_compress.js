// Reduz uma foto no próprio aparelho antes de enviar ou guardar offline: lado
// maior com até 1600 px, em JPEG. Uma foto de celular (3 a 6 MB) vira algo como
// 300 a 500 KB, o que importa com internet fraca no campo e no espaço do Blob.
// Se o navegador não conseguir ler a imagem, devolve o arquivo original.
export async function compressImage(file, { maxSize = 1600, quality = 0.82 } = {}) {
  if (!file || !file.type?.startsWith("image/")) return file

  try {
    const image = await loadImage(file)
    const width = image.width || image.naturalWidth
    const height = image.height || image.naturalHeight
    if (!width || !height) return file

    const scale = Math.min(1, maxSize / Math.max(width, height))
    const canvas = document.createElement("canvas")
    canvas.width = Math.round(width * scale)
    canvas.height = Math.round(height * scale)
    canvas.getContext("2d").drawImage(image, 0, 0, canvas.width, canvas.height)
    image.close?.()

    const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", quality))
    if (!blob) return file
    if (file.type === "image/jpeg" && scale === 1 && blob.size >= file.size) return file

    const name = `${(file.name || "foto").replace(/\.[^.]+$/, "")}.jpg`
    return new File([blob], name, { type: "image/jpeg", lastModified: Date.now() })
  } catch {
    return file
  }
}

async function loadImage(file) {
  if (window.createImageBitmap) {
    try {
      return await createImageBitmap(file, { imageOrientation: "from-image" })
    } catch {}
  }

  const url = URL.createObjectURL(file)
  try {
    const image = new Image()
    image.src = url
    await image.decode()
    return image
  } finally {
    URL.revokeObjectURL(url)
  }
}
