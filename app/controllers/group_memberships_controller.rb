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

  def promote
    return unless authorize_group_admin
    membership = @group.group_memberships.find_by!(user_id: params[:user_id])
    membership.update!(role: :organizer)
    redirect_to group_path(@group), notice: "#{membership.user.first_name} is now a co-organizer."
  end

  def demote
    return unless authorize_group_admin
    membership = @group.group_memberships.find_by!(user_id: params[:user_id])
    if @group.created_by == membership.user
      redirect_to group_path(@group), alert: "The group creator cannot be demoted."
      return
    end
    membership.update!(role: :member)
    redirect_to group_path(@group), notice: "#{membership.user.first_name} is now a member."
  end

  private

  def set_group
    @group = Group.find_by!(slug: params[:group_slug])
  end

  def authorize_group_admin
    unless @group.organizer?(current_user)
      redirect_to group_path(@group), alert: "You are not authorized to perform this action."
      return false
    end
    true
  end
end
