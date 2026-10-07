class GroupPausesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group
  before_action :authorize_group_admin

  def create
    @group.pause!(until_date: params[:paused_until].presence)
    notice = if @group.paused_until
      "#{@group.name} is paused until #{@group.paused_until.strftime("%b %-d")}. No reminders will go out until then."
    else
      "#{@group.name} is paused. No reminders will go out until you resume it."
    end
    redirect_to group_path(@group), notice: notice
  rescue ActiveRecord::RecordInvalid
    redirect_to group_path(@group), alert: "Resume date must be in the future."
  end

  def destroy
    @group.resume!
    redirect_to group_path(@group), notice: "#{@group.name} is back on. Reminders will resume as normal."
  end

  private

  def set_group
    @group = Group.find_by!(slug: params[:group_slug])
  end

  def authorize_group_admin
    unless @group.organizer?(current_user)
      redirect_to group_path(@group), alert: "You are not authorized to perform this action."
    end
  end
end
