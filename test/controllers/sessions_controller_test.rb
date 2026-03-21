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

  test "submit_phone rejects unknown phone number" do
    SmsService.stub(:send_message, true) do
      post sign_in_submit_phone_path, params: { phone: "5550000000" }
    end
    assert_response :unprocessable_entity
    assert_match /no account found/i, flash[:error]
  end

  test "submit_phone writes OTP to cache even if SMS raises" do
    with_memory_cache do
      SmsService.stub(:send_message, ->(to:, body:) { raise "Twilio down" }) do
        post sign_in_submit_phone_path, params: { phone: @phone }
      end
      assert_redirected_to sign_in_verify_path
      assert Rails.cache.read("otp:#{@phone}").present?
    end
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
    otp = "123456"
    with_memory_cache do
      SmsService.stub(:send_message, true) do
        post sign_in_submit_phone_path, params: { phone: @phone }
      end
      Rails.cache.write("otp:#{@phone}", otp, expires_in: 10.minutes)
      post sign_in_submit_verify_path, params: { code: otp }
    end
    assert_redirected_to dashboard_path
    assert_match /welcome back/i, flash[:notice]
  end

  test "submit_verify with wrong code re-renders verify" do
    with_memory_cache do
      SmsService.stub(:send_message, true) do
        post sign_in_submit_phone_path, params: { phone: @phone }
      end
      Rails.cache.write("otp:#{@phone}", "999999", expires_in: 10.minutes)
      post sign_in_submit_verify_path, params: { code: "000000" }
    end
    assert_response :unprocessable_entity
    assert_match /didn't match/i, flash[:error]
  end

  test "submit_verify with correct code but user deleted between steps renders verify with error" do
    otp = "123456"
    with_memory_cache do
      SmsService.stub(:send_message, true) do
        post sign_in_submit_phone_path, params: { phone: @phone }
      end
      Rails.cache.write("otp:#{@phone}", otp, expires_in: 10.minutes)
      @user.destroy
      post sign_in_submit_verify_path, params: { code: otp }
    end
    assert_response :unprocessable_entity
    assert_match /no account found/i, flash[:error]
  end

  test "submit_verify with expired OTP re-renders verify" do
    with_memory_cache do
      SmsService.stub(:send_message, true) do
        post sign_in_submit_phone_path, params: { phone: @phone }
      end
      # Don't write OTP — simulates expiry
      post sign_in_submit_verify_path, params: { code: "123456" }
    end
    assert_response :unprocessable_entity
    assert_match /didn't match/i, flash[:error]
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
