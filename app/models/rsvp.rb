class Rsvp < ApplicationRecord
  belongs_to :event_occurrence
  belongs_to :user, optional: true

  validates :status, presence: true, inclusion: { in: %w[attending declined maybe] }
  validates :user_id, uniqueness: { scope: :event_occurrence_id }, allow_nil: true
  validates :guest_count, numericality: { greater_than_or_equal_to: 0 }
  validate :user_or_guest_name_present

  def guest_rsvp?
    user_id.nil?
  end

  def display_name
    return user.full_name if user.present?
    guest_name.presence || "Guest"
  end

  private

  def user_or_guest_name_present
    errors.add(:base, "Must have either a user or a guest name") if user_id.blank? && guest_name.blank?
  end
end
