class BiometryEventsController < StockingEventPagesController
  OFFLINE_ACTIONS = %i[offline offline_data sync sync_photo].freeze

  skip_before_action :load_batch_stockings, :load_selected_batch_stocking, :load_current_avg_weight,
    :load_loading_form_collections, only: OFFLINE_ACTIONS
  before_action :load_previous_biometry_data, only: [:index]

  # Biometria em campo: a tela é só a estrutura (sem dados da empresa nem do
  # usuário), para o service worker poder guardá-la e abri-la sem internet. Os
  # tanques vêm de offline_data e ficam no aparelho.
  def offline
    render layout: "offline_app"
  end

  # Tanques dos lotes ativos, com o saldo e a última biometria (para a prévia
  # dos cálculos), mais um token novo para o envio.
  def offline_data
    tenant_name = session[:tenant_name].presence
    return render(json: { error: "Selecione uma empresa para usar a biometria em campo." }, status: :unprocessable_content) unless tenant_name

    company = Apartment::Tenant.switch("public") { Company.find_by(tenant_name: tenant_name) }

    render json: {
      tenant: tenant_name,
      company_name: company&.name,
      user: { id: current_user.id, name: current_user.name.presence || current_user.email },
      csrf_token: form_authenticity_token,
      generated_at: Time.current.iso8601,
      batch_stockings: offline_batch_stockings
    }
  end

  # Recebe uma foto tirada offline, depois que a biometria dela já foi enviada
  # (sync). Sem duplicar: a mesma foto (photo_uuid) reenviada só é confirmada.
  def sync_photo
    event = StockingEvent.find_by(client_uuid: params[:entry_uuid].to_s, event_type: "biometrics")
    return render(json: { status: "error", errors: ["A biometria desta foto ainda não foi enviada."] }, status: :unprocessable_content) unless event

    photo_uuid = params[:photo_uuid].to_s
    return render(json: { status: "error", errors: ["Foto sem identificador."] }, status: :unprocessable_content) unless photo_uuid.match?(/\A[0-9a-f-]{36}\z/i)

    if (existing = BiometryPhoto.find_by(client_uuid: photo_uuid))
      return render(json: { status: "duplicate", id: existing.id })
    end

    photo = BiometryPhoto.attach!(event, params[:photo], client_uuid: photo_uuid)
    render json: { status: "created", id: photo.id }
  rescue BiometryPhoto::Error => e
    render json: { status: "error", errors: [e.message] }, status: :unprocessable_content
  rescue ActiveRecord::RecordNotUnique
    render json: { status: "duplicate", id: BiometryPhoto.find_by(client_uuid: photo_uuid)&.id }
  end

  # Recebe as biometrias lançadas offline. Responde o resultado de cada uma
  # (created / duplicate / error) para o aparelho tirar da fila o que entrou.
  def sync
    entries = params.permit(entries: [:uuid, :tenant, :created_at, *OfflineBiometrySync::FIELDS])[:entries]
    results = OfflineBiometrySync.new((entries || []).map(&:to_h), tenant_name: session[:tenant_name].to_s).call

    render json: { results: results }
  end

  def create
    @stocking_event = StockingEvent.new(event_params.merge(event_type: event_type))

    if @stocking_event.save
      redirect_to redirect_path_for(@stocking_event.batch_stocking_id),
        notice: success_message, alert: attach_photos(@stocking_event)
    else
      @selected_batch_stocking = @stocking_event.batch_stocking
      @events = filtered_events(@selected_batch_stocking&.id)
      load_previous_biometry_data

      render :index, status: :unprocessable_content
    end
  end

  def edit
    @stocking_event = StockingEvent.find(params[:id])
    @selected_batch_stocking = @stocking_event.batch_stocking
    @events = filtered_events(@selected_batch_stocking&.id)
    load_previous_biometry_data

    render :index
  end

  def update
    @stocking_event = StockingEvent.find(params[:id])
    @stocking_event.assign_attributes(event_params)

    if @stocking_event.save
      redirect_to redirect_path_for(@stocking_event.batch_stocking_id),
        notice: "Biometria atualizada com sucesso.", alert: attach_photos(@stocking_event)
    else
      @selected_batch_stocking = @stocking_event.batch_stocking
      @events = filtered_events(@selected_batch_stocking&.id)
      load_previous_biometry_data

      render :index, status: :unprocessable_content
    end
  end

  def destroy
    @stocking_event = StockingEvent.find(params[:id])
    batch_stocking_id = @stocking_event.batch_stocking_id
    @stocking_event.destroy
    redirect_to redirect_path_for(batch_stocking_id), notice: "Biometria removida com sucesso."
  end

  private

  def event_type
    "biometrics"
  end

  def redirect_path_for(batch_stocking_id)
    biometry_events_path(batch_stocking_id:)
  end

  def success_message
    "Biometria lançada com sucesso."
  end

  def event_params
    params.require(:stocking_event).permit(
      :batch_stocking_id,
      :occurred_on,
      :volume,
      :quantity,
      :total_weight_kg,
      :avg_weight_g,
      :biomass,
      :weight_gain_kg,
      :gpd,
      :feed_kg,
      :feed_conversion,
      :notes
    )
  end

  # Guarda as fotos escolhidas no formulário. A biometria já foi salva: uma foto
  # que falhar não desfaz o lançamento, só vira um aviso (devolvido para o flash).
  def attach_photos(event)
    uploads = Array(params[:photos]).select { |upload| upload.respond_to?(:original_filename) }
    return nil if uploads.empty?

    errors = uploads.filter_map do |upload|
      BiometryPhoto.attach!(event, upload)
      nil
    rescue BiometryPhoto::Error => e
      e.message
    end

    errors.any? ? "#{errors.size} foto(s) não foram guardadas: #{errors.uniq.join('; ')}." : nil
  end

  def offline_batch_stockings
    BatchStocking
      .includes(:batch, pond: :unit)
      .joins(:batch, pond: :unit)
      .where(batches: { status: "active" })
      .order("units.name ASC", "ponds.order_number ASC", "ponds.id ASC", "batch_stockings.stocked_on DESC")
      .map do |batch_stocking|
        last = batch_stocking.stocking_events.where(event_type: "biometrics").order(occurred_on: :desc, created_at: :desc).first

        {
          id: batch_stocking.id,
          unit: batch_stocking.pond.unit.name,
          pond: batch_stocking.pond.name,
          batch: batch_stocking.batch.name,
          current_quantity: batch_stocking.current_quantity,
          last_biometry: last && {
            occurred_on: last.occurred_on&.iso8601,
            avg_weight_g: last.avg_weight_g&.to_f,
            biomass: last.biomass&.to_f
          }
        }
      end
  end

  def load_previous_biometry_data
    @previous_biomass = 0
    @previous_avg_weight = 0
    @previous_occurred_on = nil
    @current_avg_weight_g = 0

    @units = Unit.order(:name)
    @selected_unit_id = params[:unit_id].presence
    @ponds = @selected_unit_id.present? ? Pond.where(unit_id: @selected_unit_id).ordered : Pond.ordered
    @selected_pond_id = params[:pond_id].presence

    @active_batch_stockings =
      BatchStocking
        .includes(:batch, :pond, biometry_events: :biometry_photos)
        .joins(:batch, pond: :unit)
        .where(batches: { status: "active" })

    @active_batch_stockings = @active_batch_stockings.where(ponds: { unit_id: @selected_unit_id }) if @selected_unit_id.present?
    @active_batch_stockings = @active_batch_stockings.where(pond_id: @selected_pond_id) if @selected_pond_id.present?

    @active_batch_stockings = @active_batch_stockings.order("units.name ASC", "ponds.order_number ASC", "ponds.id ASC", "batch_stockings.stocked_on DESC")

    return unless @selected_batch_stocking.present?

    last_biometry = StockingEvent
      .where(event_type: event_type, batch_stocking_id: @selected_batch_stocking.id)
      .where.not(id: @stocking_event&.id)
      .order(occurred_on: :desc, created_at: :desc)
      .first

    Rails.logger.info("Last biometry for BatchStocking ##{@selected_batch_stocking.id}: #{last_biometry.inspect}")

    @previous_biomass = last_biometry&.biomass.to_f
    @previous_avg_weight = last_biometry&.avg_weight_g.to_f
    @previous_occurred_on = last_biometry&.occurred_on
    @current_avg_weight_g = last_biometry&.avg_weight_g.to_f
  end
end
