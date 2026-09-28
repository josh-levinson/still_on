require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Sessions controller looks up User.exists?(phone_number: phone) where phone
    # is digits-only after gsub(/\D/, ""). Onboarding stores phone_number without
    # the +1 prefix, so we match that format here.
    @phone = "5551#{rand(100_000..999_999)}"
    @user = create_user(phone_number: @phone)
  end

  # --- GET /sign_in ---

  test "phone renders sign-in page for guest" do
    get sign_in_path
    assert_response :success
  end

  test "phone redirects signed-in user to dashboard" do
    sign_in(@user)
    get sign_in_path
    assert_redirected_to dashboard_path
  end

  # --- POST /sign_in ---

  test "submit_phone stores phone in session and redirects to verify" do
    SmsService.stub(:send_message, true) do
      post sign_in_submit_phone_path, params: { phone: @phone }
    end
    assert_redirected_to sign_in_verify_path
  end

  test "submit_phone rejects short phone number" do
    post sign_in_submit_phone_path, params: { phone: "123" }
    assert_response :unprocessable_entity
    assert_match /valid 10-digit/i, flash[:error]
  end

  test "submit_phone with unknown number responds like a known one but sends nothing" do
    SmsService.stub(:send_message, ->(**) { flunk "should not text an unknown number" }) do
      post sign_in_submit_phone_path, params: { phone: "5550000000" }
    end
    assert_redirected_to sign_in_verify_path
    assert_nil session[:signin_otp]

    follow_redirect!
    assert_response :success
    assert_match /if \(555\) 000-0000 has a StillOn account/i, response.body
  end

  test "submit_verify for unknown number rejects any code" do
    post sign_in_submit_phone_path, params: { phone: "5550000000" }
    post sign_in_submit_verify_path, params: { code: "123456" }
    assert_response :unprocessable_entity
    assert_match /didn't match/i, flash[:error]
    assert_nil session[:user_id]
  end

  test "resend_otp for unknown number sends nothing and clears any old code" do
    SmsService.stub(:send_message, true) do
      post sign_in_submit_phone_path, params: { phone: @phone }
    end
    assert session[:signin_otp].present?

    SmsService.stub(:send_message, ->(**) { flunk "should not text an unknown number" }) do
      post sign_in_submit_phone_path, params: { phone: "5550000000" }
      post sign_in_resend_otp_path
    end
    assert_redirected_to sign_in_verify_path
    assert_nil session[:signin_otp]
    assert_nil session[:signin_otp_expires_at]
  end

  test "submit_phone writes OTP to session even if SMS raises" do
    SmsService.stub(:send_message, ->(to:, body:) { raise "Twilio down" }) do
      post sign_in_submit_phone_path, params: { phone: @phone }
    end
    assert_redirected_to sign_in_verify_path
    assert session[:signin_otp].present?
  end

  # --- GET /sign_in/verify ---

  test "verify renders for user with signin_phone in session" do
    SmsService.stub(:send_message, true) do
      post sign_in_submit_phone_path, params: { phone: @phone }
    end
    get sign_in_verify_path
    assert_response :success
  end

  test "verify redirects to sign_in when no session phone" do
    get sign_in_verify_path
    assert_redirected_to sign_in_path
  end

  test "verify redirects signed-in user to dashboard" do
    sign_in(@user)
    get sign_in_verify_path
    assert_redirected_to dashboard_path
  end

  # --- POST /sign_in/verify ---

  test "submit_verify with correct code signs in user and redirects to dashboard" do
    SmsService.stub(:send_message, true) do
      post sign_in_submit_phone_path, params: { phone: @phone }
    end
    post sign_in_submit_verify_path, params: { code: session[:signin_otp] }
    assert_redirected_to dashboard_path
    assert_match /welcome back/i, flash[:notice]
  end

  test "signing in sets a session cookie that outlives the browser session" do
    SmsService.stub(:send_message, true) do
      post sign_in_submit_phone_path, params: { phone: @phone }
    end
    post sign_in_submit_verify_path, params: { code: session[:signin_otp] }

    session_cookie = Array(response.headers["Set-Cookie"]).join("\n").lines.find { |c| c.start_with?("_still_on_session=") }
    expires = Time.httpdate(session_cookie[/expires=([^;]+)/i, 1])
    assert_in_delta (Time.now + 60.days).to_i, expires.to_i, 60
  end

  test "submit_phone logs the code instead of texting when OTP SMS is off" do
    log = StringIO.new
    logger = ActiveSupport::Logger.new(log)
    Rails.configuration.x.stub(:otp_sms, false) do
      Rails.stub(:logger, logger) do
        SmsService.stub(:send_message, ->(**) { flunk "should not text when OTP SMS is off" }) do
          post sign_in_submit_phone_path, params: { phone: @phone }
        end
      end
    end

    assert_redirected_to sign_in_verify_path
    assert_includes log.string, "Code for #{SmsService.mask(@phone)}: #{session[:signin_otp]}"
  end

  test "submit_verify with wrong code re-renders verify" do
    SmsService.stub(:send_message, true) do
      post sign_in_submit_phone_path, params: { phone: @phone }
    end
    post sign_in_submit_verify_path, params: { code: "000000" }
    assert_response :unprocessable_entity
    assert_match /didn't match/i, flash[:error]
  end

  test "submit_verify with correct code but user deleted between steps renders verify with error" do
    SmsService.stub(:send_message, true) do
      post sign_in_submit_phone_path, params: { phone: @phone }
    end
    otp = session[:signin_otp]
    @user.destroy
    post sign_in_submit_verify_path, params: { code: otp }
    assert_response :unprocessable_entity
    assert_match /no account found/i, flash[:error]
  end

  test "submit_verify with expired OTP re-renders verify" do
    SmsService.stub(:send_message, true) do
      post sign_in_submit_phone_path, params: { phone: @phone }
    end
    otp = session[:signin_otp]
    travel_to 11.minutes.from_now do
      post sign_in_submit_verify_path, params: { code: otp }
    end
    assert_response :unprocessable_entity
    assert_match /didn't match/i, flash[:error]
  end

  test "submit_verify locks the code after too many wrong guesses" do
    with_memory_cache do
      SmsService.stub(:send_message, true) do
        post sign_in_submit_phone_path, params: { phone: @phone }
      end
      otp = session[:signin_otp]

      (OtpVerification::MAX_OTP_ATTEMPTS - 1).times do
        post sign_in_submit_verify_path, params: { code: "000000" }
        assert_match /didn't match/i, flash[:error]
      end
      post sign_in_submit_verify_path, params: { code: "000000" }
      assert_match /too many incorrect/i, flash[:error]

      post sign_in_submit_verify_path, params: { code: otp }
      assert_response :unprocessable_entity
      assert_match /too many incorrect/i, flash[:error]
      assert_nil session[:user_id]
    end
  end

  test "submit_verify accepts a freshly resent code after lockout" do
    with_memory_cache do
      SmsService.stub(:send_message, true) do
        post sign_in_submit_phone_path, params: { phone: @phone }
        OtpVerification::MAX_OTP_ATTEMPTS.times { post sign_in_submit_verify_path, params: { code: "000000" } }
        post sign_in_resend_otp_path
      end
      post sign_in_submit_verify_path, params: { code: session[:signin_otp] }
      assert_redirected_to dashboard_path
    end
  end

  test "submit_phone is rate limited per phone number" do
    with_memory_cache do
      SmsService.stub(:send_message, true) do
        SmsThrottling::SENDS_PER_PHONE_PER_HOUR.times do
          post sign_in_submit_phone_path, params: { phone: @phone }
          assert_redirected_to sign_in_verify_path
        end
        post sign_in_submit_phone_path, params: { phone: @phone }, headers: { "HTTP_REFERER" => sign_in_url }
      end
      assert_redirected_to sign_in_url
      assert_match /too many attempts/i, flash[:alert]
    end
  end

  test "resend_otp shares the per-phone limit with submit_phone" do
    with_memory_cache do
      SmsService.stub(:send_message, true) do
        post sign_in_submit_phone_path, params: { phone: @phone }
        (SmsThrottling::SENDS_PER_PHONE_PER_HOUR - 1).times { post sign_in_resend_otp_path }
        post sign_in_resend_otp_path
      end
      assert_redirected_to root_path
      assert_match /too many attempts/i, flash[:alert]
    end
  end

  test "submit_phone is rate limited per IP across different numbers" do
    with_memory_cache do
      SmsService.stub(:send_message, true) do
        SmsThrottling::SENDS_PER_IP_PER_HOUR.times do |i|
          post sign_in_submit_phone_path, params: { phone: "555000#{i.to_s.rjust(4, "0")}" }
        end
        post sign_in_submit_phone_path, params: { phone: @phone }
      end
      assert_match /too many attempts/i, flash[:alert]
    end
  end

  test "submit_verify is rate limited per IP" do
    with_memory_cache do
      SmsThrottling::VERIFIES_PER_IP_PER_10_MIN.times do
        post sign_in_submit_verify_path, params: { code: "000000" }
      end
      post sign_in_submit_verify_path, params: { code: "000000" }
      assert_redirected_to root_path
      assert_match /too many attempts/i, flash[:alert]
    end
  end

  # --- POST /sign_in/resend ---

  test "resend_otp sends new OTP and redirects back to verify" do
    SmsService.stub(:send_message, true) do
      post sign_in_submit_phone_path, params: { phone: @phone }
      post sign_in_resend_otp_path
    end
    assert_redirected_to sign_in_verify_path
    assert_match /resent/i, flash[:notice]
  end

  test "resend_otp redirects to sign_in when no session phone" do
    post sign_in_resend_otp_path
    assert_redirected_to sign_in_path
  end

  test "resend_otp continues even if SMS raises" do
    SmsService.stub(:send_message, true) do
      post sign_in_submit_phone_path, params: { phone: @phone }
    end
    SmsService.stub(:send_message, ->(to:, body:) { raise "Twilio down" }) do
      post sign_in_resend_otp_path
    end
    assert_redirected_to sign_in_verify_path
  end

  # --- DELETE /sign_out ---

  test "destroy signs out user and redirects to root" do
    sign_in(@user)
    delete sign_out_path
    assert_redirected_to root_path
    assert_match /signed out/i, flash[:notice]
  end

  test "destroy on unauthenticated session still redirects to root" do
    delete sign_out_path
    assert_redirected_to root_path
  end
end
