class SiloStockEntry < ApplicationRecord
  include Loggable

  belongs_to :silo, optional: true
  belongs_to :feeding_type
  belongs_to :feeding_brand
  belongs_to :batch, optional: true
  belongs_to :payment_method, optional: true
  belongs_to :payment_term, optional: true

  # Uma entrada parcelada gera um lançamento financeiro por parcela.
  has_many :financial_entries, dependent: :destroy

  before_validation :sync_feeding_brand_from_type
  before_validation :calculate_price_per_kg_cents
  before_validation :apply_payment_term_due_date

  validates :occurred_on, presence: true
  validates :quantity_kg, presence: true, numericality: { greater_than: 0 }
  validates :total_cents, numericality: { greater_than_or_equal_to: 0 }
  # silo e lote são opcionais, mas quando informados precisam existir
  validates :silo, presence: true, if: -> { silo_id.present? }
  validates :batch, presence: true, if: -> { batch_id.present? }

  after_commit :sync_financial_entries!, on: %i[create update]
  after_commit :remove_financial_entries!, on: :destroy

  scope :recent_first, -> { order(occurred_on: :desc, created_at: :desc) }

  # Lançamento financeiro "principal" (a 1ª parcela). Mantido por conveniência /
  # compatibilidade -- para o cronograma completo use `financial_entries`.
  def financial_entry
    sorted_financial_entries.first
  end

  # Datas de vencimento efetivamente geradas (uma por parcela).
  def due_dates
    sorted_financial_entries.map(&:occurred_on)
  end

  # Cronograma de parcelas: usa a condição de pagamento quando houver, senão
  # cai numa parcela única na `due_on` (ou na data do lançamento).
  def payment_schedule
    if payment_term.present?
      payment_term.installment_schedule(occurred_on, total_cents.to_i)
    else
      [{ number: 1, of: 1, due_on: due_on.presence || occurred_on, amount_cents: total_cents.to_i }]
    end
  end

  private

  # Ordena em memória para aproveitar o preload (includes) e não disparar
  # query por linha na listagem.
  def sorted_financial_entries
    financial_entries.sort_by { |entry| [entry.occurred_on, entry.id] }
  end

  def activity_description
    financial_description
  end

  def sync_feeding_brand_from_type
    self.feeding_brand = feeding_type&.feeding_brand
  end

  def calculate_price_per_kg_cents
    self.price_per_kg_cents = 0

    return if quantity_kg.blank? || quantity_kg.to_d <= 0

    self.price_per_kg_cents = (total_cents.to_i / quantity_kg.to_d).round
  end

  # Com uma condição de pagamento, o vencimento é a data da 1ª parcela
  # (data do lançamento + dias da condição). Sem condição, respeita o que o
  # usuário informou.
  def apply_payment_term_due_date
    return if payment_term.blank? || occurred_on.blank?

    first_installment = payment_term.installment_schedule(occurred_on, total_cents.to_i).first
    self.due_on = first_installment[:due_on] if first_installment
  end

  # Regera os lançamentos financeiros a cada save. FinancialEntry exige valor
  # positivo, então uma entrada de valor zero (ex.: ração doada) não gera nada.
  def sync_financial_entries!
    return if destroyed? || marked_for_destruction?

    remove_financial_entries!
    return if total_cents.to_i <= 0

    payment_schedule.each do |installment|
      amount_cents = installment[:amount_cents].to_i
      next if amount_cents <= 0

      FinancialEntry.create!(
        entry_type: "expense",
        stage: batch&.stage || "general",
        occurred_on: installment[:due_on],
        amount_cents: amount_cents,
        description: financial_description(installment),
        unit_id: silo&.unit_id || batch&.unit&.id,
        batch_id: batch_id,
        silo_stock_entry_id: id
      )
    end
  end

  def remove_financial_entries!
    FinancialEntry.where(silo_stock_entry_id: id).delete_all
  end

  def financial_description(installment = nil)
    feed_label = [feeding_type&.name, feeding_brand&.name].compact.join(" ")
    label = ["Ração (estoque)", feed_label.presence, silo&.name, batch&.name].compact.join(" - ")

    return label unless installment && installment[:of].to_i > 1

    "#{label} (#{installment[:number]}/#{installment[:of]})"
  end
end
