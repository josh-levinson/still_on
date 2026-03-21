require "test_helper"

class SendCancellationNotificationJobTest < ActiveSupport::TestCase
  setup do
    @organizer  = create_user(phone_number: "+15550001001", phone_verified_at: Time.current)
    @group      = create_group(@organizer)
    @event      = create_event(@group, @organizer, title: "Friday Hangout")
    @occurrence = create_occurrence(@event, start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours, status: "cancelled")
    @attendee   = create_user(phone_number: "+15550001002", phone_verified_at: Time.current)
    create_rsvp(@occurrence, user: @attendee, status: "attending")
  end

  test "sends SMS to attending users" do
    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendCancellationNotificationJob.perform_now(@occurrence.id)
    end

    assert_equal 1, messages.length
    assert_equal @attendee.phone_number, messages.first[:to]
  end

  test "SMS body mentions event title and cancellation" do
    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendCancellationNotificationJob.perform_now(@occurrence.id)
    end

    assert_match "Friday Hangout", messages.first[:body]
    assert_match /cancelled/i, messages.first[:body]
  end

  test "sends SMS to maybe RSVPs" do
    maybe_user = create_user(phone_number: "+15550001003", phone_verified_at: Time.current)
    create_rsvp(@occurrence, user: maybe_user, status: "maybe")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendCancellationNotificationJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_includes phones, maybe_user.phone_number
  end

  test "does not send SMS to declined RSVPs" do
    declined = create_user(phone_number: "+15550001004", phone_verified_at: Time.current)
    create_rsvp(@occurrence, user: declined, status: "declined")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendCancellationNotificationJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_not_includes phones, declined.phone_number
  end

  test "skips users who have opted out" do
    SmsOptOut.opt_out!(@attendee.phone_number)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendCancellationNotificationJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "skips users without a verified phone number" do
    @attendee.update!(phone_verified_at: nil)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendCancellationNotificationJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "sends SMS to guest RSVPs with a phone number" do
    create_rsvp(@occurrence, guest_phone: "+15550001005", status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendCancellationNotificationJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_includes phones, "+15550001005"
  end

  test "skips guest RSVPs without a phone number" do
    create_rsvp(@occurrence, guest_phone: nil, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendCancellationNotificationJob.perform_now(@occurrence.id)
    end

    # only the original @attendee with a phone
    assert_equal 1, messages.length
  end

  test "sends to multiple attendees" do
    second = create_user(phone_number: "+15550001006", phone_verified_at: Time.current)
    create_rsvp(@occurrence, user: second, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendCancellationNotificationJob.perform_now(@occurrence.id)
    end

    assert_equal 2, messages.length
  end
end
