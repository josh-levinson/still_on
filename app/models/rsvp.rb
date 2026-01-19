class Rsvp < ApplicationRecord
  belongs_to :event_occurrence
  belongs_to :user

  validates :status, presence: true, inclusion: { in: %w[attending declined maybe] }
  validates :user_id, uniqueness: { scope: :event_occurrence_id }
  validates :guest_count, numericality: { greater_than_or_equal_to: 0 }
end
