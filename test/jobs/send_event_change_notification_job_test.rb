require "test_helper"

class SendEventChangeNotificationJobTest < ActiveSupport::TestCase
  setup do
    @organizer  = create_user(phone_number: "+15550003001", phone_verified_at: Time.current)
    @group      = create_group(@organizer)
    @event      = create_event(@group, @organizer, title: "Weekly Run")
    @occurrence = create_occurrence(@event, start_time: 5.days.from_now, end_time: 5.days.from_now + 1.hour)
    @attendee   = create_user(phone_number: "+15550003002", phone_verified_at: Time.current)
    create_rsvp(@occurrence, user: @attendee, status: "attending")

    @old_start_time = 4.days.from_now
    @old_location   = "Old Park"
  end

  test "sends SMS to attending users when time changes" do
    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "start_time" ], @old_start_time.iso8601, @old_location
      )
    end

    phones = messages.map { |m| m[:to] }
    assert_includes phones, @attendee.phone_number
  end

  test "SMS body mentions time change" do
    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "start_time" ], @old_start_time.iso8601, @old_location
      )
    end

    assert_match "Weekly Run", messages.first[:body]
    assert_match /moved to/i, messages.first[:body]
  end

  test "sends SMS to attending users when location changes" do
    @occurrence.update!(location: "New Park")
    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "location" ], @old_start_time.iso8601, @old_location
      )
    end

    assert_match "New Park", messages.first[:body]
    assert_match /location has changed/i, messages.first[:body]
  end

  test "SMS body contains a guest RSVP link" do
    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "start_time" ], @old_start_time.iso8601, @old_location
      )
    end

    assert_match(/\/rsvp\//, messages.first[:body])
  end

  test "sends to maybe RSVPs" do
    maybe_user = create_user(phone_number: "+15550003003", phone_verified_at: Time.current)
    create_rsvp(@occurrence, user: maybe_user, status: "maybe")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "start_time" ], @old_start_time.iso8601, @old_location
      )
    end

    phones = messages.map { |m| m[:to] }
    assert_includes phones, maybe_user.phone_number
  end

  test "does not send to declined RSVPs" do
    declined = create_user(phone_number: "+15550003004", phone_verified_at: Time.current)
    create_rsvp(@occurrence, user: declined, status: "declined")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "start_time" ], @old_start_time.iso8601, @old_location
      )
    end

    phones = messages.map { |m| m[:to] }
    assert_not_includes phones, declined.phone_number
  end

  test "does not send when occurrence is cancelled" do
    @occurrence.update!(status: "cancelled")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "start_time" ], @old_start_time.iso8601, @old_location
      )
    end

    assert_empty messages
  end

  test "skips users who have opted out" do
    SmsOptOut.opt_out!(@attendee.phone_number)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "start_time" ], @old_start_time.iso8601, @old_location
      )
    end

    assert_empty messages
  end

  test "skips users without a verified phone" do
    @attendee.update!(phone_verified_at: nil)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "start_time" ], @old_start_time.iso8601, @old_location
      )
    end

    assert_empty messages
  end

  test "sends to guest RSVPs with a phone number" do
    create_rsvp(@occurrence, guest_phone: "+15550003005", status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "start_time" ], @old_start_time.iso8601, @old_location
      )
    end

    phones = messages.map { |m| m[:to] }
    assert_includes phones, "+15550003005"
  end

  test "location change falls back to event location when occurrence has no location" do
    @event.update!(location: "Event HQ")
    # occurrence.location is nil by default

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "location" ], @old_start_time.iso8601, @old_location
      )
    end

    assert_match "Event HQ", messages.first[:body]
  end

  test "location change falls back to TBD when neither occurrence nor event has a location" do
    # neither @occurrence nor @event has a location set

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "location" ], @old_start_time.iso8601, @old_location
      )
    end

    assert_match "TBD", messages.first[:body]
  end

  test "handles both time and location changes in one message" do
    @occurrence.update!(location: "New Park")
    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "start_time", "location" ], @old_start_time.iso8601, @old_location
      )
    end

    assert_match /moved to/i, messages.first[:body]
    assert_match /location has changed/i, messages.first[:body]
  end

  test "sends email to user with unverified phone but valid email" do
    unverified = create_user(phone_number: "+15550003099", phone_verified_at: nil, email: "unverified@example.com")
    create_rsvp(@occurrence, user: unverified, status: "attending")

    sms_recipients = []
    SmsService.stub(:send_message, ->(to:, body:) { sms_recipients << to }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "start_time" ], @old_start_time.iso8601, @old_location
      )
    end

    assert_not_includes sms_recipients, "+15550003099"
    email = ActionMailer::Base.deliveries.find { |m| m.to.include?("unverified@example.com") }
    assert_not_nil email
  ensure
    ActionMailer::Base.deliveries.clear
  end

  test "skips attending RSVPs with no phone at all" do
    create_rsvp(@occurrence, status: "attending")  # no user, no guest_phone

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventChangeNotificationJob.perform_now(
        @occurrence.id, [ "start_time" ], @old_start_time.iso8601, @old_location
      )
    end

    phones = messages.map { |m| m[:to] }
    assert_not_includes phones, nil
    assert_equal 1, messages.size  # only the verified attendee with a phone
  end
end
