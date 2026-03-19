class BatchPond < ApplicationRecord
  belongs_to :batch
  belongs_to :pond

  validates :pond_id, uniqueness: { scope: :batch_id }
end
