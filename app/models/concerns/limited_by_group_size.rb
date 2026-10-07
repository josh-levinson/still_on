# Each record of an including model is someone who gets the group's automated
# texts, so new ones are refused once the group reaches Group::MAX_PEOPLE.
module LimitedByGroupSize
  extend ActiveSupport::Concern

  included do
    validate :group_has_room, on: :create
  end

  private

  def group_has_room
    errors.add(:group, "is full") if group&.full?
  end
end
