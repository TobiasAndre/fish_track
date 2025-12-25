class BatchEvent < ApplicationRecord
  belongs_to :batch
  has_one :company, through: :batch

  enum event_type: {
    biometrics: "biometrics",     # biometria
    mortality: "mortality",       # mortalidade
    feeding: "feeding",           # arraçoamento / ração
    daily_care: "daily_care",     # trato diário
    loading: "loading",           # carregamento (movimentação/saída)
    transfer: "transfer"          # transferência (opcional)
  }

  validates :event_type, presence: true
  validates :occurred_on, presence: true

  # campos comuns
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # campos por tipo (você pode refinar depois)
  validates :avg_weight_g, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :feed_kg, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
