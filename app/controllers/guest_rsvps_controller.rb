class GuestRsvpsController < ApplicationController
  before_action :load_occurrence_from_token

  def show
    @existing_rsvp = find_existing_rsvp
    @rsvp = @existing_rsvp || @event_occurrence.rsvps.new(status: "attending")
  end

  def create
    @existing_rsvp = find_existing_rsvp

    if @existing_rsvp
      if @existing_rsvp.update(rsvp_params)
        redirect_to guest_rsvp_path(@token), notice: "RSVP updated!"
      else
        @rsvp = @existing_rsvp
        render :show, status: :unprocessable_entity
      end
      return
    end

    @rsvp = @event_occurrence.rsvps.new(rsvp_params)

    if current_user
      @rsvp.user = current_user
    end

    if @rsvp.save
      redirect_to guest_rsvp_path(@token), notice: rsvp_confirmation_message(@rsvp)
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_occurrence_from_token
    @token = params[:token]
    @event_occurrence, @prefilled_phone = EventOccurrence.find_by_invite_token(@token)

    if @event_occurrence.nil?
      render plain: "This invite link is invalid or has expired.", status: :not_found
    else
      @event = @event_occurrence.event
      @group = @event.group
    end
  end

  def find_existing_rsvp
    if current_user
      @event_occurrence.rsvps.find_by(user_id: current_user.id)
    elsif @prefilled_phone.present?
      @event_occurrence.rsvps.find_by(guest_phone: @prefilled_phone)
    end
  end

  def rsvp_params
    permitted = params.require(:rsvp).permit(:status, :guest_count, :notes, :guest_name, :guest_phone)
    # Authenticated users don't need/use guest identity fields
    current_user ? permitted.except(:guest_name, :guest_phone) : permitted
  end

  def rsvp_confirmation_message(rsvp)
    case rsvp.status
    when "attending" then "You're in! See you there."
    when "maybe"     then "Got it — marked as maybe."
    when "declined"  then "No worries, you're marked as not coming."
    end
  end
end
