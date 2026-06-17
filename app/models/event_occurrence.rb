class EventOccurrence < ApplicationRecord
  belongs_to :event
  has_many :rsvps, dependent: :destroy

  before_create :ensure_invite_token

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

  def maybe_count
    rsvps.where(status: "maybe").count
  end

  def declined_count
    rsvps.where(status: "declined").count
  end

  def responded_count
    rsvps.count
  end

  def no_response_count(member_count)
    [ member_count - responded_count, 0 ].max
  end

  def full?
    max_attendees.present? && attending_count >= max_attendees
  end

  # Look up an occurrence by its short, random invite token. Returns nil when
  # the token is blank or doesn't match a record. Phone prefill for SMS
  # recipients is handled separately via a query param, not the token.
  def self.find_by_invite_token(token)
    return nil if token.blank?
    find_by(invite_token: token)
  end

  private

  def ensure_invite_token
    return if invite_token.present?

    self.invite_token = loop do
      candidate = SecureRandom.urlsafe_base64(8)
      break candidate unless self.class.exists?(invite_token: candidate)
    end
  end

  def end_time_after_start_time
    return unless start_time.present? && end_time.present?

    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
end
