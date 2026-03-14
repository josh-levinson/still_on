class EventOccurrencesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group
  before_action :set_event
  before_action :set_event_occurrence, only: [ :show, :edit, :update, :destroy, :cancel ]
  before_action :authorize_occurrence_admin, only: [ :edit, :update, :destroy, :cancel ]

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
      redirect_to [ @group, @event, @event_occurrence ], notice: "Event occurrence was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    old_start_time = @event_occurrence.start_time
    old_location = @event_occurrence.location
    was_scheduled = @event_occurrence.status == "scheduled"

    if @event_occurrence.update(event_occurrence_params)
      if was_scheduled && @event_occurrence.status == "cancelled"
        SendCancellationNotificationJob.perform_later(@event_occurrence.id)
      elsif @event_occurrence.status == "scheduled"
        changed_fields = []
        changed_fields << "start_time" if @event_occurrence.start_time != old_start_time
        changed_fields << "location" if @event_occurrence.location != old_location

        if changed_fields.any?
          SendEventChangeNotificationJob.perform_later(
            @event_occurrence.id,
            changed_fields,
            old_start_time.iso8601,
            old_location
          )
        end
      end

      redirect_to [ @group, @event, @event_occurrence ], notice: "Event occurrence was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def cancel
    if @event_occurrence.status == "scheduled"
      @event_occurrence.update!(status: "cancelled")
      SendCancellationNotificationJob.perform_later(@event_occurrence.id)
      redirect_to [ @group, @event, @event_occurrence ], notice: "Occurrence cancelled and attendees will be notified."
    else
      redirect_to [ @group, @event, @event_occurrence ], alert: "This occurrence is not scheduled."
    end
  end

  def destroy
    @event_occurrence.destroy
    redirect_to group_event_event_occurrences_url(@group, @event), notice: "Event occurrence was successfully deleted."
  end

  private

  def set_group
    @group = Group.find_by!(slug: params[:group_slug])
  end

  def set_event
    @event = @group.events.find(params[:event_id])
  end

  def set_event_occurrence
    @event_occurrence = @event.event_occurrences.find(params[:id])
  end

  def authorize_occurrence_admin
    unless @event.created_by == current_user || @group.created_by == current_user
      redirect_to [ @group, @event, @event_occurrence ], alert: "You are not authorized to perform this action."
    end
  end

  def event_occurrence_params
    params.require(:event_occurrence).permit(
      :start_time, :end_time, :location, :status, :max_attendees, :notes
    )
  end
end
