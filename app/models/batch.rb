class Batch < ApplicationRecord
 belongs_to :pond
  has_one :unit, through: :pond
  has_one :company, through: :unit

  has_many :batch_events, dependent: :destroy
  has_many :financial_entries, dependent: :nullify

  enum stage: { nursery: "nursery", juvenile: "juvenile", growout: "growout" }
  enum status: { active: "active", closed: "closed" }

  validates :name, :status, :stage, :started_on, presence: true

  def recalculate_from_events!
    with_lock do
      events = batch_events.order(occurred_on: :asc, created_at: :asc)

      # ---- QUANTIDADE ----
      if initial_quantity.present?
        qty = initial_quantity.to_i

        events.each do |e|
          case e.event_type
          when "mortality"
            qty -= e.quantity.to_i
          when "loading"
            qty = 0
          end
        end

        qty = 0 if qty.negative?
        self.current_quantity = qty
      end

      # ---- PESO MÉDIO (última biometria) ----
      last_bio = events
        .select { |e| e.event_type == "biometrics" && e.avg_weight_g.present? }
        .last

      self.avg_weight_g = last_bio&.avg_weight_g

      # ---- STATUS DO LOTE ----
      loading_event = events.reverse.find { |e| e.event_type == "loading" }

      if loading_event
        self.status = "closed"
        self.closed_on = loading_event.occurred_on
      else
        self.status = "active"
        self.closed_on = nil
      end

      save!(validate: false)
    end
  end
end
