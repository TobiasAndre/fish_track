# Remove uma foto de um lançamento de biometria (na edição).
class BiometryPhotosController < ApplicationController
  before_action :authenticate_user!

  def destroy
    event = StockingEvent.where(event_type: "biometrics").find(params[:biometry_event_id])
    event.biometry_photos.find(params[:id]).destroy!

    redirect_to edit_biometry_event_path(event), notice: "Foto removida."
  end
end
