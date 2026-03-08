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

  # Signed invite token — encodes this occurrence's ID and an optional phone
  # number for SMS recipients. URL-safe via outer Base64 encoding.
  def invite_token(phone: nil)
    payload = { oid: id.to_s }
    payload[:phone] = phone if phone.present?
    raw = Rails.application.message_verifier(:guest_rsvp).generate(payload)
    Base64.urlsafe_encode64(raw, padding: false)
  end

  def self.find_by_invite_token(token)
    raw = Base64.urlsafe_decode64(token)
    payload = Rails.application.message_verifier(:guest_rsvp).verify(raw)
    occurrence = find(payload["oid"])
    [ occurrence, payload["phone"] ]
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError,
         ActiveRecord::RecordNotFound
    [ nil, nil ]
  end

  private

  def end_time_after_start_time
    return unless start_time.present? && end_time.present?

    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
end
