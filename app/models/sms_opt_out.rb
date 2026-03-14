class SmsOptOut < ApplicationRecord
  validates :phone_number, presence: true, uniqueness: true

  def self.opted_out?(phone_number)
    exists?(phone_number: phone_number)
  end

  def self.opt_out!(phone_number)
    find_or_create_by!(phone_number: phone_number)
  end
end
