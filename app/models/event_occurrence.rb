class EventOccurrence < ApplicationRecord
  belongs_to :event
  has_many :rsvps, dependent: :destroy

  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :status, presence: true, inclusion: { in: %w[scheduled cancelled completed] }
  validate :end_time_after_start_time

  scope :upcoming, -> { where("start_time > ?", Time.current).order(start_time: :asc) }
  scope :past, -> { where("start_time <= ?", Time.current).order(start_time: :desc) }
  scope :scheduled, -> { where(status: "scheduled") }

  def attending_count
    rsvps.where(status: "attending").sum("1 + guest_count")
  end

  def full?
    max_attendees.present? && attending_count >= max_attendees
  end

  private

  def end_time_after_start_time
    return unless start_time.present? && end_time.present?

    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
end
