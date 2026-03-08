class SendRsvpReminderJob < ApplicationJob
  queue_as :notifications

  def perform(event_occurrence_id)
    occurrence = EventOccurrence
      .includes(event: { group: { group_memberships: :user } }, rsvps: [])
      .find(event_occurrence_id)

    return unless occurrence.status == "scheduled"
    return if occurrence.start_time <= Time.current

    event = occurrence.event
    date_str = occurrence.start_time.strftime("%A, %B %-d")
    rsvp_url = rsvp_url_for(event, occurrence)
    message = "Still on for #{event.title} on #{date_str}? RSVP here: #{rsvp_url}"

    unresvped_members(occurrence).each do |user|
      SmsService.send_message(to: user.phone_number, body: message)
    end
  end

  private

  def unresvped_members(occurrence)
    rsvped_user_ids = occurrence.rsvps.pluck(:user_id).to_set

    occurrence.event.group.group_memberships
      .includes(:user)
      .map(&:user)
      .select { |u| u.phone_number.present? && !rsvped_user_ids.include?(u.id) }
  end

  def rsvp_url_for(event, occurrence)
    Rails.application.routes.url_helpers.event_occurrence_rsvps_url(
      event_id: event.id,
      event_occurrence_id: occurrence.id,
      host: Rails.application.credentials.dig(:app, :host) || ENV["APP_HOST"] || "localhost:3000"
    )
  end
end
