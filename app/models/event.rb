class Event < ApplicationRecord
  belongs_to :group
  belongs_to :created_by, class_name: "User"
  has_many :event_occurrences, dependent: :destroy

  validates :title, presence: true
  validates :recurrence_type, presence: true, inclusion: { in: %w[none daily weekly monthly] }

  scope :active, -> { where(is_active: true) }
  scope :recurring, -> { where.not(recurrence_type: "none") }
end
