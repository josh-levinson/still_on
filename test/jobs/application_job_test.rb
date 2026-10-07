require "test_helper"

# Minimal subclass to exercise ApplicationJob#notify directly.
class NotifyTestJob < ApplicationJob
  def perform(phone: nil, email: nil, subject: nil, body: "test message")
    notify(phone: phone, email: email, subject: subject, body: body)
  end
end

class ApplicationJobTest < ActiveSupport::TestCase
  def twilio_error
    fake_response = Struct.new(:status_code, :body).new(400, { "code" => 21211, "message" => "err" })
    Twilio::REST::RestError.new("Error", fake_response)
  end

  test "falls back to email and logs a warning when SMS raises RestError" do
    warned = []
    Rails.logger.stub(:warn, ->(msg) { warned << msg }) do
      SmsService.stub(:send_message, ->(**_) { raise twilio_error }) do
        NotifyTestJob.perform_now(phone: "+15550001111", email: "fallback@example.com", body: "Hi")
      end
    end

    assert_equal 1, ActionMailer::Base.deliveries.length
    assert_equal [ "fallback@example.com" ], ActionMailer::Base.deliveries.first.to
    assert_match "[notify] SMS failed", warned.first
  end

  test "does not report the SMS failure again (SmsService already did)" do
    SmsService.stub(:send_message, ->(**_) { raise twilio_error }) do
      assert_no_error_reported do
        NotifyTestJob.perform_now(phone: "+15550001111", email: "fallback@example.com", body: "Hi")
      end
    end
  end

  test "masks the phone number in the fallback warning" do
    warned = []
    Rails.logger.stub(:warn, ->(msg) { warned << msg }) do
      SmsService.stub(:send_message, ->(**_) { raise twilio_error }) do
        NotifyTestJob.perform_now(phone: "+15550001111", email: "fallback@example.com", body: "Hi")
      end
    end

    assert_includes warned.first, "***1111"
    assert_not_includes warned.first, "5550001111"
  end

  test "check_in pings Honeybadger with the ID from the env var" do
    pinged = []
    ENV["HONEYBADGER_CHECKIN_NOTIFY_TEST"] = "abc123"
    Honeybadger.stub(:check_in, ->(id) { pinged << id }) do
      NotifyTestJob.new.send(:check_in, :notify_test)
    end

    assert_equal [ "abc123" ], pinged
  ensure
    ENV.delete("HONEYBADGER_CHECKIN_NOTIFY_TEST")
  end

  test "check_in does nothing when the env var is unset" do
    pinged = []
    Honeybadger.stub(:check_in, ->(id) { pinged << id }) do
      NotifyTestJob.new.send(:check_in, :notify_test)
    end

    assert_empty pinged
  end

  test "sends nothing when both phone and email are absent" do
    messages = []
    SmsService.stub(:send_message, ->(**_) { messages << true }) do
      NotifyTestJob.perform_now
    end

    assert_empty messages
    assert_empty ActionMailer::Base.deliveries
  end

  test "sends email directly when phone is absent but email is present" do
    NotifyTestJob.perform_now(email: "direct@example.com", subject: "Hey", body: "No phone needed")

    assert_equal 1, ActionMailer::Base.deliveries.length
    assert_equal [ "direct@example.com" ], ActionMailer::Base.deliveries.first.to
    assert_equal "Hey", ActionMailer::Base.deliveries.first.subject
  end

  test "reports and swallows email delivery failures" do
    failing_mail = Object.new
    def failing_mail.deliver_now = raise(Resend::Error, "invalid address")

    EventMailer.stub(:notification, failing_mail) do
      assert_error_reported(Resend::Error) do
        NotifyTestJob.perform_now(email: "bad@example.com", body: "Hi")
      end
    end
  end

  test "uses default subject when none provided" do
    NotifyTestJob.perform_now(email: "no-subject@example.com", body: "Something")

    assert_equal "StillOn notification", ActionMailer::Base.deliveries.first.subject
  end

  teardown do
    ActionMailer::Base.deliveries.clear
  end
end
