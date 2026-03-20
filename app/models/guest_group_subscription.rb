class GuestGroupSubscription < ApplicationRecord
  belongs_to :group

  validates :phone_number, presence: true
  validates :phone_number, uniqueness: { scope: :group_id }

  def self.subscribe(group:, phone_number:)
    find_or_create_by(group: group, phone_number: phone_number)
  end

  def self.unsubscribe(group:, phone_number:)
    find_by(group: group, phone_number: phone_number)&.destroy
  end
end
