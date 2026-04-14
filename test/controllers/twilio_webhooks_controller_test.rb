require "test_helper"

class TwilioWebhooksControllerTest < ActionDispatch::IntegrationTest
  # valid_twilio_request? returns true in test env, so no signature needed

  # ---- POST /twilio/sms ----

  test "returns 200 for any incoming SMS" do
    post twilio_sms_webhook_path, params: { From: "+15555550101", Body: "Hello there" }
    assert_response :ok
  end

  test "opts out user on STOP keyword" do
    assert_difference "SmsOptOut.count", 1 do
      post twilio_sms_webhook_path, params: { From: "+15555550102", Body: "STOP" }
    end
    assert_response :ok
    assert SmsOptOut.opted_out?("5555550102")
  end

  test "opts out user on UNSUBSCRIBE keyword" do
    assert_difference "SmsOptOut.count", 1 do
      post twilio_sms_webhook_path, params: { From: "+15555550103", Body: "UNSUBSCRIBE" }
    end
    assert SmsOptOut.opted_out?("5555550103")
  end

  test "opts out user on CANCEL keyword" do
    assert_difference "SmsOptOut.count", 1 do
      post twilio_sms_webhook_path, params: { From: "+15555550104", Body: "CANCEL" }
    end
    assert SmsOptOut.opted_out?("5555550104")
  end

  test "opts out user on END keyword" do
    assert_difference "SmsOptOut.count", 1 do
      post twilio_sms_webhook_path, params: { From: "+15555550105", Body: "END" }
    end
    assert SmsOptOut.opted_out?("5555550105")
  end

  test "opts out user on QUIT keyword" do
    assert_difference "SmsOptOut.count", 1 do
      post twilio_sms_webhook_path, params: { From: "+15555550106", Body: "QUIT" }
    end
    assert SmsOptOut.opted_out?("5555550106")
  end

  test "opts out user on STOPALL keyword" do
    assert_difference "SmsOptOut.count", 1 do
      post twilio_sms_webhook_path, params: { From: "+15555550107", Body: "STOPALL" }
    end
    assert SmsOptOut.opted_out?("5555550107")
  end

  test "does not opt out on non-stop body" do
    assert_no_difference "SmsOptOut.count" do
      post twilio_sms_webhook_path, params: { From: "+15555550108", Body: "Yes I'll be there!" }
    end
    assert_response :ok
  end

  test "opt-out is idempotent — duplicate STOP does not raise" do
    SmsOptOut.opt_out!("5555550109")
    assert_no_difference "SmsOptOut.count" do
      post twilio_sms_webhook_path, params: { From: "+15555550109", Body: "STOP" }
    end
    assert_response :ok
  end

  test "strips country code prefix when recording opt-out" do
    post twilio_sms_webhook_path, params: { From: "+15555550110", Body: "STOP" }
    assert SmsOptOut.opted_out?("5555550110")
    assert_not SmsOptOut.opted_out?("+15555550110")
  end

  test "handles body with surrounding whitespace" do
    assert_difference "SmsOptOut.count", 1 do
      post twilio_sms_webhook_path, params: { From: "+15555550111", Body: "  stop  " }
    end
    assert_response :ok
  end

  test "returns 403 when Twilio signature is invalid" do
    original = TwilioWebhooksController.instance_method(:valid_twilio_request?)
    TwilioWebhooksController.define_method(:valid_twilio_request?) { false }
    post twilio_sms_webhook_path, params: { From: "+15555550199", Body: "STOP" }
    assert_response :forbidden
  ensure
    TwilioWebhooksController.define_method(:valid_twilio_request?, original)
  end

  test "valid_twilio_request? validates Twilio signature outside test environment" do
    controller = TwilioWebhooksController.new
    mock_request = Struct.new(:url, :POST, :headers).new(
      "https://example.com/twilio/sms", {}, { "X-Twilio-Signature" => "abc123" }
    )
    controller.instance_variable_set(:@_request, mock_request)

    validate_calls = []
    validator = Object.new
    validator.define_singleton_method(:validate) { |*args| validate_calls << args; true }

    Rails.env.stub(:test?, false) do
      Twilio::Security::RequestValidator.stub(:new, validator) do
        assert controller.send(:valid_twilio_request?)
      end
    end

    assert_equal 1, validate_calls.length
    assert_equal [ "https://example.com/twilio/sms", {}, "abc123" ], validate_calls.first
  end
end
