class GroupMembershipsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group

  def create
    if @group.member?(current_user)
      redirect_to group_path(@group.slug), alert: "You are already a member of this group."
      return
    end

    if @group.is_private
      redirect_to group_path(@group.slug), alert: "This group is private and not open to new members."
      return
    end

    @group.group_memberships.create!(user: current_user)
    redirect_to group_path(@group.slug), notice: "You have joined #{@group.name}."
  end

  def destroy
    if @group.created_by == current_user
      redirect_to group_path(@group.slug), alert: "The group creator cannot leave the group."
      return
    end

    membership = @group.group_memberships.find_by(user: current_user)
    if membership
      membership.destroy
      redirect_to groups_path, notice: "You have left #{@group.name}."
    else
      redirect_to group_path(@group.slug), alert: "You are not a member of this group."
    end
  end

  private

  def set_group
    @group = Group.find_by!(slug: params[:group_slug])
  end
end
