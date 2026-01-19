class EventOccurrencesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group
  before_action :set_event
  before_action :set_event_occurrence, only: [:show, :edit, :update, :destroy]
  before_action :authorize_occurrence_admin, only: [:edit, :update, :destroy]

  def index
    @upcoming_occurrences = @event.event_occurrences.upcoming
    @past_occurrences = @event.event_occurrences.past
  end

  def show
    @rsvps = @event_occurrence.rsvps.includes(:user).order(created_at: :asc)
    @user_rsvp = @event_occurrence.rsvps.find_by(user: current_user)
  end

  def new
    @event_occurrence = @event.event_occurrences.new(
      start_time: Time.current,
      end_time: Time.current + (@event.default_duration_minutes || 60).minutes,
      location: @event.location
    )
  end

  def create
    @event_occurrence = @event.event_occurrences.new(event_occurrence_params)

    if @event_occurrence.save
      redirect_to [@group, @event, @event_occurrence], notice: "Event occurrence was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @event_occurrence.update(event_occurrence_params)
      redirect_to [@group, @event, @event_occurrence], notice: "Event occurrence was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event_occurrence.destroy
    redirect_to group_event_event_occurrences_url(@group, @event), notice: "Event occurrence was successfully deleted."
  end

  private

  def set_group
    @group = Group.find_by!(slug: params[:group_id])
  end

  def set_event
    @event = @group.events.find(params[:event_id])
  end

  def set_event_occurrence
    @event_occurrence = @event.event_occurrences.find(params[:id])
  end

  def authorize_occurrence_admin
    unless @event.created_by == current_user || @group.created_by == current_user
      redirect_to [@group, @event, @event_occurrence], alert: "You are not authorized to perform this action."
    end
  end

  def event_occurrence_params
    params.require(:event_occurrence).permit(
      :start_time, :end_time, :location, :status, :max_attendees, :notes
    )
  end
end
