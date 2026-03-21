require "test_helper"

class SmsServiceTest < ActiveSupport::TestCase
  setup do
    @received = []
    @messages_mock = Object.new
    @messages_mock.define_singleton_method(:create) { |**kwargs| @received << kwargs }
    received = @received
    @messages_mock.define_singleton_method(:create) { |**kwargs| received << kwargs }

    @client_mock = Object.new
    messages_mock = @messages_mock
    @client_mock.define_singleton_method(:messages) { messages_mock }
  end

  test "send_message instance method calls Twilio client with correct args" do
    ENV["TWILIO_FROM_NUMBER"] = "+15550001111"

    Twilio::REST::Client.stub(:new, @client_mock) do
      SmsService.new.send_message(to: "+15559999999", body: "Hello test")
    end

    assert_equal 1, @received.length
    assert_equal "+15559999999", @received.first[:to]
    assert_equal "Hello test", @received.first[:body]
    assert_equal "+15550001111", @received.first[:from]
  end

  test "self.send_message class method delegates to instance" do
    Twilio::REST::Client.stub(:new, @client_mock) do
      SmsService.send_message(to: "+15559999998", body: "Class method test")
    end

    assert_equal 1, @received.length
    assert_equal "+15559999998", @received.first[:to]
  end

  test "send_message re-raises Twilio::REST::RestError after logging" do
    fake_response = Struct.new(:status_code, :body).new(400, { "code" => 21211, "message" => "err" })
    error = Twilio::REST::RestError.new("Error", fake_response)

    bad_messages = Object.new
    bad_messages.define_singleton_method(:create) { |**_| raise error }
    bad_client = Object.new
    bad_client.define_singleton_method(:messages) { bad_messages }

    Twilio::REST::Client.stub(:new, bad_client) do
      assert_raises Twilio::REST::RestError do
        SmsService.new.send_message(to: "+15559999997", body: "Will fail")
      end
    end
  end
end
