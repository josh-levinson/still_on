class DashboardController < ApplicationController
  before_action :authenticate_user!

  # One card per hangout, split by the user's role in it: hangouts they run get
  # an RSVP tally and organizer actions; hangouts they're in get their own RSVP.
  def show
    @organized_groups = Group
      .where(created_by: current_user)
      .or(Group.where(id: current_user.group_memberships.organizers.select(:group_id)))
      .order(:name)

    @attending_groups = Group
      .where(id: current_user.group_memberships.select(:group_id))
      .or(Group.where(id: GuestGroupSubscription.where(phone_number: current_user.phone_number).select(:group_id)))
      .or(Group.where(id: Event.joins(event_occurrences: :rsvps).where(rsvps: { user_id: current_user.id }).select(:group_id)))
      .where.not(id: @organized_groups.select(:id))
      .order(:name)
  end
end
