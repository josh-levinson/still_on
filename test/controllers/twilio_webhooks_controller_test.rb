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

  %w[START YES UNSTOP].each do |keyword|
    test "opts user back in on #{keyword} keyword" do
      SmsOptOut.opt_out!("5555550112")
      assert_difference "SmsOptOut.count", -1 do
        post twilio_sms_webhook_path, params: { From: "+15555550112", Body: keyword.downcase }
      end
      assert_response :ok
      assert_not SmsOptOut.opted_out?("5555550112")
    end
  end

  test "START for a number that never opted out is a no-op" do
    assert_no_difference "SmsOptOut.count" do
      post twilio_sms_webhook_path, params: { From: "+15555550113", Body: "START" }
    end
    assert_response :ok
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

  # ---- POST /twilio/status ----

  def capture_honeybadger(&block)
    notices = []
    Honeybadger.stub(:notify, ->(*args, **kwargs) { notices << [ args, kwargs ] }, &block)
    notices
  end

  %w[failed undelivered].each do |status|
    test "reports a #{status} message to Honeybadger, fingerprinted by error code" do
      notices = capture_honeybadger do
        post twilio_status_webhook_path, params: { MessageSid: "SM123", MessageStatus: status, ErrorCode: "30007", To: "+15555550101" }
      end

      assert_response :ok
      assert_equal 1, notices.length
      args, kwargs = notices.first
      assert_equal "SMS #{status} (Twilio error 30007)", args.first
      assert_equal "Twilio::DeliveryFailure", kwargs[:error_class]
      assert_equal "Twilio::DeliveryFailure-30007", kwargs[:fingerprint]
      assert_equal({ message_sid: "SM123", message_status: status, twilio_code: "30007" }, kwargs[:context])
    end
  end

  %w[queued sent delivered].each do |status|
    test "does not report a #{status} message" do
      notices = capture_honeybadger do
        post twilio_status_webhook_path, params: { MessageSid: "SM123", MessageStatus: status }
      end

      assert_response :ok
      assert_empty notices
    end
  end

  test "status callback returns 403 when Twilio signature is invalid" do
    original = TwilioWebhooksController.instance_method(:valid_twilio_request?)
    TwilioWebhooksController.define_method(:valid_twilio_request?) { false }
    notices = capture_honeybadger do
      post twilio_status_webhook_path, params: { MessageSid: "SM123", MessageStatus: "failed", ErrorCode: "30007" }
    end
    assert_response :forbidden
    assert_empty notices
  ensure
    TwilioWebhooksController.define_method(:valid_twilio_request?, original)
  end

  # ---- POST /twilio/debugger ----

  def debugger_params(error_code, level: "ERROR")
    {
      Sid: "NO123", AccountSid: "AC123", Level: level, PayloadType: "application/json",
      Payload: { resource_sid: "SM456", error_code: error_code, more_info: { Msg: "To: +15555550101" } }.to_json
    }
  end

  test "reports a debugger alert with only the code and SIDs" do
    notices = capture_honeybadger do
      post twilio_debugger_webhook_path, params: debugger_params("11200")
    end

    assert_response :ok
    args, kwargs = notices.first
    assert_equal "Twilio error 11200", args.first
    assert_equal "Twilio::DebuggerAlert", kwargs[:error_class]
    assert_equal "Twilio::DebuggerAlert-11200", kwargs[:fingerprint]
    assert_equal({ level: "ERROR", sid: "NO123", resource_sid: "SM456", twilio_code: "11200" }, kwargs[:context])
    assert_not_includes kwargs.to_s, "5555550101"
  end

  test "reports debugger warnings too" do
    notices = capture_honeybadger do
      post twilio_debugger_webhook_path, params: debugger_params("12300", level: "WARNING")
    end

    assert_equal "Twilio warning 12300", notices.first.first.first
  end

  test "skips message delivery errors that the status callback already reports" do
    notices = capture_honeybadger do
      post twilio_debugger_webhook_path, params: debugger_params("30007")
    end

    assert_response :ok
    assert_empty notices
  end

  test "still reports when the debugger payload is not valid JSON" do
    notices = capture_honeybadger do
      post twilio_debugger_webhook_path, params: { Sid: "NO123", Level: "ERROR", Payload: "not json" }
    end

    assert_response :ok
    assert_equal "Twilio::DebuggerAlert-", notices.first.last[:fingerprint]
  end
end
