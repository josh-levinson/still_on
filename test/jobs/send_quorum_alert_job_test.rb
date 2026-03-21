require "test_helper"

class SendQuorumAlertJobTest < ActiveSupport::TestCase
  setup do
    @organizer  = create_user(phone_number: "+15550002001", phone_verified_at: Time.current)
    @group      = create_group(@organizer)
    @event      = create_event(@group, @organizer, title: "Book Club", quorum: 5)
    @occurrence = create_occurrence(@event, start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours)
    @attendee   = create_user(phone_number: "+15550002002", phone_verified_at: Time.current)
    create_rsvp(@occurrence, user: @attendee, status: "attending")
  end

  test "sends alert to organizer when quorum is not met" do
    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    organizer_message = messages.find { |m| m[:to] == @organizer.phone_number }
    assert_not_nil organizer_message
  end

  test "organizer alert body mentions event title and quorum" do
    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    organizer_message = messages.find { |m| m[:to] == @organizer.phone_number }
    assert_match "Book Club", organizer_message[:body]
    assert_match "5", organizer_message[:body]
  end

  test "sends alert to attending RSVPs" do
    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_includes phones, @attendee.phone_number
  end

  test "sends alert to maybe RSVPs" do
    maybe_user = create_user(phone_number: "+15550002003", phone_verified_at: Time.current)
    create_rsvp(@occurrence, user: maybe_user, status: "maybe")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_includes phones, maybe_user.phone_number
  end

  test "does not send when quorum is met" do
    5.times { create_rsvp(@occurrence, user: create_user(phone_verified_at: Time.current), status: "attending") }

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "does not send when event has no quorum set" do
    @event.update!(quorum: nil)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "does not send when occurrence is cancelled" do
    @occurrence.update!(status: "cancelled")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "skips organizer who has opted out" do
    SmsOptOut.opt_out!(@organizer.phone_number)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_not_includes phones, @organizer.phone_number
  end

  test "skips organizer without verified phone" do
    @organizer.update!(phone_verified_at: nil)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_not_includes phones, @organizer.phone_number
  end

  test "sends alert to guest attendees who have a phone number" do
    create_rsvp(@occurrence, guest_phone: "+15550002010", status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_includes phones, "+15550002010"
  end

  test "skips attendee RSVPs with no phone" do
    create_rsvp(@occurrence, status: "attending")  # no user, no guest_phone

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_not_includes phones, nil
  end

  test "skips attendees with user who has an unverified phone" do
    unverified = create_user(phone_number: "+15550002011", phone_verified_at: nil)
    create_rsvp(@occurrence, user: unverified, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_not_includes phones, "+15550002011"
  end

  test "skips attendees who have opted out" do
    SmsOptOut.opt_out!(@attendee.phone_number)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_not_includes phones, @attendee.phone_number
  end

  test "skips organizer with no phone number" do
    @organizer.update!(phone_number: nil)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendQuorumAlertJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_not_includes phones, nil
  end
end
