class GroupMembership < ApplicationRecord
  include LimitedByGroupSize

  belongs_to :group
  belongs_to :user

  validates :user_id, uniqueness: { scope: :group_id }

  enum :role, { member: "member", organizer: "organizer" }, default: "member"

  scope :organizers, -> { where(role: "organizer") }
end
