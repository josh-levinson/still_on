class RsvpsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event_occurrence
  before_action :set_rsvp, only: [:edit, :update, :destroy]
  before_action :authorize_rsvp_owner, only: [:edit, :update, :destroy]

  def create
    @rsvp = @event_occurrence.rsvps.new(rsvp_params)
    @rsvp.user = current_user

    if @rsvp.save
      redirect_to group_event_event_occurrence_path(
        @event_occurrence.event.group.slug,
        @event_occurrence.event,
        @event_occurrence
      ), notice: "RSVP was successfully created."
    else
      redirect_to group_event_event_occurrence_path(
        @event_occurrence.event.group.slug,
        @event_occurrence.event,
        @event_occurrence
      ), alert: @rsvp.errors.full_messages.join(", ")
    end
  end

  def update
    if @rsvp.update(rsvp_params)
      redirect_to group_event_event_occurrence_path(
        @event_occurrence.event.group.slug,
        @event_occurrence.event,
        @event_occurrence
      ), notice: "RSVP was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rsvp.destroy
    redirect_to group_event_event_occurrence_path(
      @event_occurrence.event.group.slug,
      @event_occurrence.event,
      @event_occurrence
    ), notice: "RSVP was successfully deleted."
  end

  private

  def set_event_occurrence
    @event_occurrence = EventOccurrence.find(params[:event_occurrence_id])
  end

  def set_rsvp
    @rsvp = @event_occurrence.rsvps.find(params[:id])
  end

  def authorize_rsvp_owner
    unless @rsvp.user == current_user
      redirect_to group_event_event_occurrence_path(
        @event_occurrence.event.group.slug,
        @event_occurrence.event,
        @event_occurrence
      ), alert: "You are not authorized to perform this action."
    end
  end

  def rsvp_params
    params.require(:rsvp).permit(:status, :guest_count, :notes)
  end
end
