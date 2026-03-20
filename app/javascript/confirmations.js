import { Turbo } from "@hotwired/turbo-rails"
import Swal from "sweetalert2"

Turbo.config.forms.confirm = async function (message, element) {
  const isDeleteAction =
    element?.dataset?.turboMethod === "delete" ||
    element?.closest("form")?.querySelector('input[name="_method"][value="delete"]')

  const result = await Swal.fire({
    title: isDeleteAction ? "Tem certeza?" : "Confirmação",
    text: message,
    icon: isDeleteAction ? "warning" : "question",
    showCancelButton: true,
    confirmButtonText: isDeleteAction ? "Sim, excluir" : "Confirmar",
    cancelButtonText: "Cancelar",
    reverseButtons: true,
    focusCancel: true,
    allowOutsideClick: true,
    buttonsStyling: false,
    customClass: {
      popup: "swal2-popup-custom",
      title: "swal2-title-custom",
      htmlContainer: "swal2-text-custom",
      confirmButton: isDeleteAction ? "swal2-confirm-danger" : "swal2-confirm-primary",
      cancelButton: "swal2-cancel-custom"
    }
  })

  return result.isConfirmed
}
