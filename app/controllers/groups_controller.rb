class GroupsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group, only: [:show, :edit, :update, :destroy]
  before_action :authorize_group_admin, only: [:edit, :update, :destroy]

  def index
    @groups = current_user.groups.order(name: :asc)
  end

  def show
    @events = @group.events.active.order(created_at: :desc)
  end

  def new
    @group = Group.new
  end

  def create
    @group = Group.new(group_params)
    @group.created_by = current_user

    if @group.save
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
    @group = Group.find_by!(slug: params[:id])
  end

  def authorize_group_admin
    unless @group.created_by == current_user
      redirect_to @group, alert: "You are not authorized to perform this action."
    end
  end

  def group_params
    params.require(:group).permit(:name, :description, :avatar_url, :is_private)
  end
end
