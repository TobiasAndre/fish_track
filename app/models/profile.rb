class Profile < ApplicationRecord
  belongs_to :user, optional: true
  # optional true porque User vive no public
  # e não tem FK real no banco

  validates :user_id, presence: true, uniqueness: true
end
