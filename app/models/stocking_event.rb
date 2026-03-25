class StockingEvent < ApplicationRecord
  belongs_to :batch_stocking

  EVENT_TYPES = %w[biometrics mortality feeding loading].freeze

  enum event_type: {
    biometrics: "biometrics",
    mortality: "mortality",
    feeding: "feeding",
    loading: "loading"
  }, _suffix: true

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :occurred_on, presence: true
  before_validation :calculate_biometry_fields
  after_commit :update_batch_avg_weight, on: %i[create update]

  private

  def update_batch_avg_weight
    return unless biometria?

    batch = batch_stocking&.batch
    return unless batch

    last_biometry = batch_stocking.stocking_events
      .where(event_type: "biometrics")
      .order(occurred_on: :desc, created_at: :desc)
      .first

    return unless last_biometry&.avg_weight_g.present?

    batch.update(avg_weight_g: last_biometry.avg_weight_g)
  end

  def calculate_biometry_fields
    return unless biometria?

    if quantity.present? && total_weight_kg.present? && quantity.to_d > 0
      self.avg_weight_g = (total_weight_kg.to_d / quantity.to_d) * 1000
    end

    if volume.present? && avg_weight_g.present?
      self.biomass = volume.to_d * (avg_weight_g.to_d / 1000)
    end
  end

  def biometria?
    event_type == "biometrics"
  end
end
