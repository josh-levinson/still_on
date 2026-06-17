class GuestInviteToken < ApplicationRecord
  belongs_to :event_occurrence

  validates :phone, presence: true
  validates :token, presence: true, uniqueness: true

  before_validation :ensure_token, on: :create

  # Returns the short, opaque invite token for a specific recipient of an
  # occurrence, creating it once and reusing it on subsequent sends.
  def self.for(occurrence, phone)
    find_or_create_by!(event_occurrence: occurrence, phone: phone)
  end

  private

  def ensure_token
    return if token.present?

    self.token = loop do
      candidate = SecureRandom.urlsafe_base64(8)
      break candidate unless self.class.exists?(token: candidate)
    end
  end
end
