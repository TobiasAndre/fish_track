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
end
