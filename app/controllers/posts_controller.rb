class PostsController < ApplicationController
  def index
    if user_signed_in?
      @groups = current_user.groups.order(name: :asc)
      @upcoming_occurrences = EventOccurrence
        .joins(event: { group: :group_memberships })
        .where(group_memberships: { user_id: current_user.id })
        .upcoming
        .scheduled
        .limit(10)
    end
  end
end
