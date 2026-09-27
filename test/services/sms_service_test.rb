require "test_helper"

class SmsServiceTest < ActiveSupport::TestCase
  setup do
    @received = []
    received = @received

    @messages_mock = Object.new
    @messages_mock.define_singleton_method(:create) { |**kwargs| received << kwargs }

    @client_mock = Object.new
    messages_mock = @messages_mock
    @client_mock.define_singleton_method(:messages) { messages_mock }
  end

  test "send_message instance method calls Twilio client with correct args" do
    ENV["TWILIO_FROM_NUMBER"] = "+15550001111"

    SmsService.new(client: @client_mock).send_message(to: "+15559999999", body: "Hello test")

    assert_equal 1, @received.length
    assert_equal "+15559999999", @received.first[:to]
    assert_equal "StillOn: Hello test", @received.first[:body]
    assert_equal "+15550001111", @received.first[:from]
  end

  test "send_message does not double the StillOn prefix" do
    SmsService.new(client: @client_mock).send_message(to: "+15559999999", body: "StillOn: Already branded")

    assert_equal "StillOn: Already branded", @received.first[:body]
  end

  test "self.send_message class method delegates to instance" do
    ENV["TWILIO_FROM_NUMBER"] = "+15550001111"
    Twilio::REST::Client.stub(:new, @client_mock) do
      SmsService.send_message(to: "+15559999998", body: "Class method test")
    end

    assert_equal 1, @received.length
    assert_equal "+15559999998", @received.first[:to]
  end

  def failing_client(error)
    bad_messages = Object.new
    bad_messages.define_singleton_method(:create) { |**_| raise error }
    bad_client = Object.new
    bad_client.define_singleton_method(:messages) { bad_messages }
    bad_client
  end

  def twilio_error
    fake_response = Struct.new(:status_code, :body).new(400, { "code" => 21211, "message" => "err" })
    Twilio::REST::RestError.new("Error", fake_response)
  end

  test "send_message reports and re-raises Twilio::REST::RestError" do
    reports = capture_error_reports(Twilio::REST::RestError) do
      assert_raises Twilio::REST::RestError do
        SmsService.new(client: failing_client(twilio_error)).send_message(to: "+15559999997", body: "Will fail")
      end
    end

    assert_equal 1, reports.length
    assert reports.first.handled
    assert_equal 21211, reports.first.context[:twilio_code]
  end

  test "send_message reports and re-raises non-Twilio errors" do
    reports = capture_error_reports(ArgumentError) do
      assert_raises ArgumentError do
        SmsService.new(client: failing_client(ArgumentError.new("bad config"))).send_message(to: "+15559999997", body: "x")
      end
    end

    assert_nil reports.first.context[:twilio_code]
  end

  test "send_message masks the phone number in the error log" do
    logged = []
    Rails.logger.stub(:error, ->(msg) { logged << msg }) do
      assert_raises Twilio::REST::RestError do
        SmsService.new(client: failing_client(twilio_error)).send_message(to: "+15559999997", body: "Will fail")
      end
    end

    assert_includes logged.first, "***9997"
    assert_not_includes logged.first, "5559999997"
  end

  test "mask keeps only the last four digits" do
    assert_equal "***1234", SmsService.mask("+1 (555) 555-1234")
    assert_equal "***", SmsService.mask(nil)
  end

  test "send_message omits status_callback when callbacks are off" do
    SmsService.new(client: @client_mock).send_message(to: "+15559999999", body: "Hi")

    assert_not @received.first.key?(:status_callback)
  end

  test "send_message passes an https status_callback when callbacks are on" do
    Rails.configuration.x.twilio_status_callbacks = true
    SmsService.new(client: @client_mock).send_message(to: "+15559999999", body: "Hi")

    assert_equal "https://example.com/twilio/status", @received.first[:status_callback]
  ensure
    Rails.configuration.x.twilio_status_callbacks = false
  end
end
