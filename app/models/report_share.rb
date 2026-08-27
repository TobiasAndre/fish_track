class ReportShare < ApplicationRecord
  has_secure_token :share_token

  REPORT_TYPES = %w[batch_report loading_report].freeze

  validates :report_type, presence: true, inclusion: { in: REPORT_TYPES }

  scope :for_type, ->(report_type) { where(report_type: report_type) }
end
