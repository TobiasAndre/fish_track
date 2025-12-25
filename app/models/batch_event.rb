class BatchEvent < ApplicationRecord
  belongs_to :batch

  enum event_type: {
    biometrics: "biometrics",
    mortality: "mortality",
    feeding: "feeding",
    daily_care: "daily_care",
    loading: "loading"
  }

  validates :occurred_on, :event_type, presence: true
  validates :quantity, presence: true, if: -> { mortality? }
  validates :avg_weight_g, presence: true, if: -> { biometrics? }

  validate :batch_must_be_active

  after_commit :recalculate_batch!, on: [:create, :update, :destroy]

  private

  def recalculate_batch!
    batch.recalculate_from_events!
  end

  def batch_must_be_active
    return if batch.active?

    errors.add(:base, "Este lote já está fechado e não pode receber novos eventos.")
  end
end
