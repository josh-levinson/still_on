require "test_helper"

class SendRsvpReminderJobTest < ActiveSupport::TestCase
  setup do
    @user       = create_user(phone_number: "+15550000001", phone_verified_at: Time.current)
    @group      = create_group(@user)
    GroupMembership.find_or_create_by!(group: @group, user: @user)
    @event      = create_event(@group, @user)
    @occurrence = create_occurrence(@event, start_time: 2.days.from_now, end_time: 2.days.from_now + 2.hours)
  end

  test "sends SMS to group members who have not RSVPed" do
    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendRsvpReminderJob.perform_now(@occurrence.id)
    end

    assert_equal 1, messages.length
    assert_equal @user.phone_number, messages.first[:to]
    assert_match "Still on for", messages.first[:body]
    assert_match @event.title, messages.first[:body]
  end

  test "SMS body contains a guest RSVP token link" do
    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendRsvpReminderJob.perform_now(@occurrence.id)
    end

    assert_match(/\/rsvp\//, messages.first[:body])
  end

  test "does not send SMS to members who already RSVPed" do
    create_rsvp(@occurrence, user: @user, status: "attending")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendRsvpReminderJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "does not send SMS to members without a phone number" do
    @user.update!(phone_number: nil)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendRsvpReminderJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "skips cancelled occurrences" do
    @occurrence.update!(status: "cancelled")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendRsvpReminderJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "skips occurrences that have already started" do
    @occurrence.update!(start_time: 1.hour.ago, end_time: Time.current)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendRsvpReminderJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "skips opted-out members" do
    SmsOptOut.opt_out!(@user.phone_number)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendRsvpReminderJob.perform_now(@occurrence.id)
    end

    assert_empty messages
  end

  test "appends occurrence notes to SMS body for members" do
    @occurrence.update!(notes: "Bring a coat")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendRsvpReminderJob.perform_now(@occurrence.id)
    end

    assert_match "Bring a coat", messages.first[:body]
  end

  test "sends to unresvped guest subscribers" do
    GuestGroupSubscription.create!(group: @group, phone_number: "+15550099001")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendRsvpReminderJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_includes phones, "+15550099001"
  end

  test "skips opted-out subscribers" do
    GuestGroupSubscription.create!(group: @group, phone_number: "+15550099002")
    SmsOptOut.opt_out!("+15550099002")

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendRsvpReminderJob.perform_now(@occurrence.id)
    end

    phones = messages.map { |m| m[:to] }
    assert_not_includes phones, "+15550099002"
  end

  test "appends occurrence notes to SMS body for subscribers" do
    @occurrence.update!(notes: "Bring snacks")
    GuestGroupSubscription.create!(group: @group, phone_number: "+15550099003")
    SmsOptOut.opt_out!(@user.phone_number)  # silence member so only subscriber message remains

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendRsvpReminderJob.perform_now(@occurrence.id)
    end

    subscriber_msg = messages.find { |m| m[:to] == "+15550099003" }
    assert_not_nil subscriber_msg
    assert_match "Bring snacks", subscriber_msg[:body]
  end

  test "sends to multiple unresponded members" do
    second_user = create_user(phone_number: "+15550000002", phone_verified_at: Time.current)
    GroupMembership.create!(group: @group, user: second_user)

    messages = []
    SmsService.stub(:send_message, ->(to:, body:) { messages << { to: to, body: body } }) do
      SendRsvpReminderJob.perform_now(@occurrence.id)
    end

    assert_equal 2, messages.length
    phones = messages.map { |m| m[:to] }
    assert_includes phones, @user.phone_number
    assert_includes phones, second_user.phone_number
  end
end
