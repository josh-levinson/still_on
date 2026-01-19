class EventsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group
  before_action :set_event, only: [:show, :edit, :update, :destroy]
  before_action :authorize_event_admin, only: [:edit, :update, :destroy]

  def index
    @events = @group.events.active.order(created_at: :desc)
  end

  def show
    @upcoming_occurrences = @event.event_occurrences.upcoming.limit(10)
    @past_occurrences = @event.event_occurrences.past.limit(5)
  end

  def new
    @event = @group.events.new
  end

  def create
    @event = @group.events.new(event_params)
    @event.created_by = current_user

    if @event.save
      redirect_to [@group, @event], notice: "Event was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @event.update(event_params)
      redirect_to [@group, @event], notice: "Event was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to group_events_url(@group), notice: "Event was successfully deleted."
  end

  private

  def set_group
    @group = Group.find_by!(slug: params[:group_id])
  end

  def set_event
    @event = @group.events.find(params[:id])
  end

  def authorize_event_admin
    unless @event.created_by == current_user || @group.created_by == current_user
      redirect_to [@group, @event], alert: "You are not authorized to perform this action."
    end
  end

  def event_params
    params.require(:event).permit(
      :title, :description, :location, :default_duration_minutes,
      :recurrence_type, :recurrence_rule, :is_active
    )
  end
end
