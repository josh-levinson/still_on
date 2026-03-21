class SendRsvpReminderJob < ApplicationJob
  queue_as :notifications

  def perform(event_occurrence_id)
    occurrence = EventOccurrence
      .includes(event: { group: { group_memberships: :user, guest_group_subscriptions: [] } }, rsvps: [])
      .find(event_occurrence_id)

    return unless occurrence.status == "scheduled"
    return if occurrence.start_time <= Time.current

    event = occurrence.event
    group = event.group
    date_str = occurrence.start_time.in_time_zone(group.time_zone).strftime("%A, %B %-d")

    unresvped_members(occurrence).each do |user|
      url = rsvp_url_for(occurrence, phone: user.phone_number)
      message = "Still on for #{event.title} on #{date_str}? RSVP here: #{url}"
      message += "\n\n#{occurrence.notes}" if occurrence.notes.present?

      notify(
        phone: user.phone_number,
        email: user.email,
        subject: "Still on for #{event.title}?",
        body: message
      )
    end

    unresvped_subscribers(occurrence).each do |phone|
      next if SmsOptOut.opted_out?(phone)

      url = rsvp_url_for(occurrence, phone: phone)
      message = "Still on for #{event.title} on #{date_str}? RSVP here: #{url}"
      message += "\n\n#{occurrence.notes}" if occurrence.notes.present?
      SmsService.send_message(to: phone, body: message)
    end
  end

  private

  def unresvped_members(occurrence)
    rsvped_user_ids = occurrence.rsvps.pluck(:user_id).to_set

    occurrence.event.group.group_memberships
      .includes(:user)
      .map(&:user)
      .select { |u| (u.phone_number.present? || u.email.present?) && !rsvped_user_ids.include?(u.id) }
  end

  def unresvped_subscribers(occurrence)
    rsvped_phones = occurrence.rsvps.pluck(:guest_phone).to_set

    occurrence.event.group.guest_group_subscriptions
      .pluck(:phone_number)
      .reject { |phone| rsvped_phones.include?(phone) }
  end

  def rsvp_url_for(occurrence, phone: nil)
    token = occurrence.invite_token(phone: phone)
    host = Rails.application.credentials.dig(:app, :host) || ENV["APP_HOST"] || "localhost:3000"
    Rails.application.routes.url_helpers.guest_rsvp_url(token, host: host)
  end
end
