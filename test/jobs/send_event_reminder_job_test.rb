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

  test "does not send SMS to non-organizer declined RSVPs" do
    other = create_user(phone_number: "+15550000020", phone_verified_at: Time.current)
    @group.group_memberships.create!(user: other)
    create_rsvp(@occurrence, user: other, status: "declined")
    create_rsvp(@occurrence, user: @user, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_equal 1, messages.length
    assert_equal @user.phone_number, messages.first[:to]
  end

  test "always sends day-of reminder to organizer even if they declined" do
    create_rsvp(@occurrence, user: @user, status: "declined")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_equal 1, messages.length
    assert_equal @user.phone_number, messages.first[:to]
  end

  test "always sends day-of reminder to organizer even without an RSVP" do
    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_equal 1, messages.length
    assert_equal @user.phone_number, messages.first[:to]
  end

  test "skips organizer for day-of reminder when they have no contact info" do
    @user.update!(phone_number: nil)
    guest = create_user(phone_number: "+15550000020", phone_verified_at: Time.current)
    create_rsvp(@occurrence, user: guest, status: "attending")
    @group.group_memberships.create!(user: guest)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_equal 1, messages.length
    assert_equal guest.phone_number, messages.first[:to]
  end

  test "sends SMS to guests via guest_phone" do
    create_rsvp(@occurrence, status: "attending", guest_name: "Sam Guest", guest_phone: "+15550000099")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert messages.any? { |m| m[:to] == "+15550000099" }, "expected guest to receive reminder"
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
    create_rsvp(@occurrence, user: @user, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_equal 1, messages.length
    assert_equal @user.phone_number, messages.first[:to]
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

  test "skips users who have disabled event_day_reminders" do
    NotificationPreference.create!(user: @user, event_day_reminders: false)
    create_rsvp(@occurrence, user: @user, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "still sends to users who have enabled event_day_reminders" do
    NotificationPreference.create!(user: @user, event_day_reminders: true)
    create_rsvp(@occurrence, user: @user, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert_equal 1, messages.length
  end

  test "still sends day-of reminder to guests regardless of notification preferences" do
    create_rsvp(@occurrence, status: "attending", guest_name: "Guest", guest_phone: "+15550000099")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendEventReminderJob.perform_now(@occurrence.id)
    end

    assert messages.any? { |m| m[:to] == "+15550000099" }, "expected guest to receive reminder"
  end
end
