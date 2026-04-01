class GroupsController < ApplicationController
  before_action :authenticate_user!, except: [ :show, :discover ]
  before_action :set_group, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_group_admin, only: [ :edit, :update, :destroy ]
  before_action :authorize_group_access, only: [ :show ]

  def index
    @groups = current_user.groups.order(name: :asc)
  end

  def discover
    @groups = Group.public_groups.order(name: :asc)
    @groups = @groups.where("name LIKE ?", "%#{params[:q]}%") if params[:q].present?
  end

  def show
    @events = @group.events.active.order(created_at: :desc)
    @upcoming_occurrences = EventOccurrence
      .joins(event: :group)
      .where(events: { group_id: @group.id }, status: "scheduled")
      .where("start_time > ?", Time.current)
      .order(:start_time)
      .limit(10)
      .includes(:rsvps, :event)
  end

  def new
    @group = Group.new(time_zone: current_user.time_zone.presence || "Eastern Time (US & Canada)")
  end

  def create
    @group = Group.new(group_params)
    @group.created_by = current_user

    if @group.save
      current_user.update_column(:time_zone, @group.time_zone)
      # Auto-add creator as a member
      @group.group_memberships.create!(user: current_user)
      redirect_to @group, notice: "Group was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @group.update(group_params)
      current_user.update_column(:time_zone, @group.time_zone)
      redirect_to @group, notice: "Group was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @group.destroy
    redirect_to groups_url, notice: "Group was successfully deleted."
  end

  private

  def set_group
    @group = Group.find_by!(slug: params[:slug])
  end

  def authorize_group_access
    return unless @group.is_private
    return if @group.member?(current_user)

    if user_signed_in?
      redirect_to groups_path, alert: "This group is private."
    else
      redirect_to sign_in_path, alert: "Please sign in to view this group."
    end
  end

  def authorize_group_admin
    unless @group.organizer?(current_user)
      redirect_to @group, alert: "You are not authorized to perform this action."
    end
  end

  def group_params
    params.require(:group).permit(:name, :description, :avatar_url, :is_private, :time_zone)
  end
end
