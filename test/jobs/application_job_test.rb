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

  test "uses default subject when none provided" do
    NotifyTestJob.perform_now(email: "no-subject@example.com", body: "Something")

    assert_equal "StillOn notification", ActionMailer::Base.deliveries.first.subject
  end

  teardown do
    ActionMailer::Base.deliveries.clear
  end
end
