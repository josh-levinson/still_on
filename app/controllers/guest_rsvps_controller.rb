class GuestRsvpsController < ApplicationController
  before_action :load_occurrence_from_token

  def show
    @existing_rsvp = find_existing_rsvp
    @rsvp = @existing_rsvp || @event_occurrence.rsvps.new(status: "attending")
    @cookie_phone = cookies[:guest_phone]
  end

  def create
    @existing_rsvp = find_existing_rsvp

    if @existing_rsvp
      if @existing_rsvp.update(rsvp_params)
        save_phone_cookie(@existing_rsvp.guest_phone)
        update_future_reminder_subscription(@existing_rsvp.guest_phone)
        redirect_to guest_rsvp_path(@token), notice: "RSVP updated!"
      else
        @rsvp = @existing_rsvp
        @cookie_phone = cookies[:guest_phone]
        render :show, status: :unprocessable_entity
      end
      return
    end

    @rsvp = @event_occurrence.rsvps.new(rsvp_params)

    if current_user
      @rsvp.user = current_user
    end

    if @rsvp.save
      save_phone_cookie(@rsvp.guest_phone)
      update_future_reminder_subscription(@rsvp.guest_phone)
      redirect_to guest_rsvp_path(@token), notice: rsvp_confirmation_message(@rsvp)
    else
      @cookie_phone = cookies[:guest_phone]
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
    else
      phone = @prefilled_phone.presence || cookies[:guest_phone].presence
      @event_occurrence.rsvps.find_by(guest_phone: phone) if phone.present?
    end
  end

  def save_phone_cookie(phone)
    if phone.present?
      cookies[:guest_phone] = { value: phone, expires: 1.year.from_now, same_site: :lax }
    else
      cookies.delete(:guest_phone)
    end
  end

  def rsvp_params
    permitted = params.require(:rsvp).permit(:status, :guest_count, :notes, :guest_name, :guest_phone)
    # Authenticated users don't need/use guest identity fields
    current_user ? permitted.except(:guest_name, :guest_phone) : permitted
  end

  def update_future_reminder_subscription(phone)
    return if current_user
    return if phone.blank?

    if params[:send_future_reminders] == "1"
      GuestGroupSubscription.subscribe(group: @group, phone_number: phone)
    else
      GuestGroupSubscription.unsubscribe(group: @group, phone_number: phone)
    end
  end

  def rsvp_confirmation_message(rsvp)
    case rsvp.status
    when "attending" then "You're in! See you there."
    when "maybe"     then "Got it — marked as maybe."
    when "declined"  then "No worries, you're marked as not coming."
    end
  end
end
