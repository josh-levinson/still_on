class User < ApplicationRecord
  has_many :created_groups, class_name: "Group", foreign_key: :created_by_id, dependent: :destroy
  has_many :created_events, class_name: "Event", foreign_key: :created_by_id, dependent: :destroy
  has_many :group_memberships, dependent: :destroy
  has_many :groups, through: :group_memberships
  has_many :rsvps, dependent: :destroy

  validates :phone_number, uniqueness: true, allow_blank: true
  validates :username, uniqueness: true, allow_nil: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true,
                    uniqueness: { case_sensitive: false, allow_blank: true }

  after_update :claim_guest_rsvps, if: -> { saved_change_to_phone_number? && phone_number.present? }

  def full_name
    [ first_name, last_name ].compact.join(" ").presence || username || phone_number
  end

  private

  # When a user verifies their phone, adopt any guest RSVPs made with that number.
  def claim_guest_rsvps
    Rsvp.where(guest_phone: phone_number, user_id: nil).find_each do |rsvp|
      # Skip if this user already has an RSVP for the same occurrence
      next if Rsvp.exists?(event_occurrence_id: rsvp.event_occurrence_id, user_id: id)

      rsvp.update_columns(user_id: id, guest_name: nil, guest_phone: nil)
    end
  end
end
