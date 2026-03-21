require "test_helper"

class SendEventReminderJobTest < ActiveSupport::TestCase
  setup do
    @user       = create_user(phone_number: "+15550000010", phone_verified_at: Time.current)
    @group      = create_group(@user)
    @event      = create_event(@group, @user)
    @occurrence = create_occurrence(@event, start_time: 4.hours.from_now, end_time: 6.hours.from_now)
  end

  test "sends SMS to attending RSVPs" do
    create_rsvp(@occurrence, user: @user, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_equal 1, messages.length
    assert_equal @user.phone_number, messages.first[:to]
    assert_match @event.title, messages.first[:body]
    assert_match "today", messages.first[:body]
  end

  test "sends SMS to maybe RSVPs" do
    create_rsvp(@occurrence, user: @user, status: "maybe")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_equal 1, messages.length
  end

  test "does not send SMS to declined RSVPs" do
    create_rsvp(@occurrence, user: @user, status: "declined")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "sends SMS to guests via guest_phone" do
    create_rsvp(@occurrence, status: "attending", guest_name: "Sam Guest", guest_phone: "+15550000099")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_equal 1, messages.length
    assert_equal "+15550000099", messages.first[:to]
  end

  test "includes location in message when present" do
    @occurrence.update!(location: "The Brewery")
    create_rsvp(@occurrence, user: @user, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_match "The Brewery", messages.first[:body]
  end

  test "falls back to event location when occurrence has none" do
    @event.update!(location: "The Park")
    create_rsvp(@occurrence, user: @user, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_match "The Park", messages.first[:body]
  end

  test "skips cancelled occurrences" do
    @occurrence.update!(status: "cancelled")
    create_rsvp(@occurrence, user: @user, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "skips occurrences that have already started" do
    @occurrence.update!(start_time: 1.hour.ago, end_time: Time.current)
    create_rsvp(@occurrence, user: @user, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "appends notes to message when occurrence has notes" do
    @occurrence.update!(notes: "Bring a chair!")
    create_rsvp(@occurrence, user: @user, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_match "Bring a chair!", messages.first[:body]
  end

  test "skips user RSVPs with no phone and no email" do
    no_contact = create_user(phone_number: nil)
    create_rsvp(@occurrence, user: no_contact, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "skips opted-out phone numbers" do
    create_rsvp(@occurrence, user: @user, status: "attending")

    messages = []
    SmsOptOut.stub(:opted_out?, ->(_phone) { true }) do
      SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
        SendEventReminderJob.perform_now(@occurrence.id)
      end
    end

    assert_empty messages
  end
end
