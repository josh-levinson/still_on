require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  # Helper to load the session with the wizard state up to a given step.
  def set_ob_session(attrs = {})
    defaults = {
      ob_first_name:   "Alex",
      ob_hangout_name: "Friday Night",
      ob_date:         1.week.from_now.to_date.to_s,
      ob_cadence:      "weekly"
    }
    defaults.merge(attrs).each do |key, value|
      session[key] = value
    end
  end

  # Run submit_cadence to create the user/group/occurrence and plant ob_occurrence_id.
  # Returns the created User.
  def complete_cadence_step(cadence: "weekly")
    post onboarding_submit_name_path, params: { first_name: "Alex", hangout_name: "Friday Night" }
    post onboarding_submit_date_path, params: { date: 1.week.from_now.to_date.to_s }
    SmsService.stub(:send_message, true) do
      post onboarding_submit_cadence_path, params: { cadence: cadence }
    end
    User.order(:created_at).last
  end

  # ---- GET /onboarding (splash) ----

  test "splash renders for guest" do
    get onboarding_splash_path
    assert_response :success
  end

  test "splash redirects signed-in user to dashboard" do
    sign_in(create_user)
    get onboarding_splash_path
    assert_redirected_to dashboard_path
  end

  # ---- GET /onboarding/name ----

  test "name renders step 1" do
    get onboarding_name_path
    assert_response :success
  end

  # ---- POST /onboarding/name ----

  test "submit_name with valid params redirects to date step" do
    post onboarding_submit_name_path, params: { first_name: "Alex", hangout_name: "Friday Night" }
    assert_redirected_to onboarding_date_path
  end

  test "submit_name with blank first_name re-renders with error" do
    post onboarding_submit_name_path, params: { first_name: "", hangout_name: "Friday Night" }
    assert_response :unprocessable_entity
    assert_match /fill in both/i, flash[:error]
  end

  test "submit_name with blank hangout_name re-renders with error" do
    post onboarding_submit_name_path, params: { first_name: "Alex", hangout_name: "" }
    assert_response :unprocessable_entity
    assert_match /fill in both/i, flash[:error]
  end

  # ---- GET /onboarding/date ----

  test "date_step renders step 2" do
    get onboarding_date_path
    assert_response :success
  end

  # ---- POST /onboarding/date ----

  test "submit_date with valid future date redirects to cadence" do
    post onboarding_submit_date_path, params: { date: 1.week.from_now.to_date.to_s }
    assert_redirected_to onboarding_cadence_path
  end

  test "submit_date with past date re-renders with error" do
    post onboarding_submit_date_path, params: { date: 2.days.ago.to_date.to_s }
    assert_response :unprocessable_entity
    assert_match /valid future date/i, flash[:error]
  end

  test "submit_date with garbage string re-renders with error" do
    post onboarding_submit_date_path, params: { date: "not-a-date" }
    assert_response :unprocessable_entity
    assert_match /valid future date/i, flash[:error]
  end

  test "submit_date with blank date re-renders with error" do
    post onboarding_submit_date_path, params: { date: "" }
    assert_response :unprocessable_entity
    assert_match /valid future date/i, flash[:error]
  end

  # ---- GET /onboarding/cadence ----

  test "cadence renders step 3" do
    post onboarding_submit_name_path, params: { first_name: "Alex", hangout_name: "Friday Night" }
    post onboarding_submit_date_path, params: { date: 1.week.from_now.to_date.to_s }
    get onboarding_cadence_path
    assert_response :success
  end

  # ---- POST /onboarding/cadence ----

  test "submit_cadence creates user, group, event, and occurrence" do
    assert_difference ["User.count", "Group.count", "Event.count", "EventOccurrence.count"], 1 do
      complete_cadence_step
    end
  end

  test "submit_cadence redirects to phone step" do
    complete_cadence_step
    assert_redirected_to onboarding_phone_path
  end

  test "submit_cadence with invalid cadence re-renders with error" do
    post onboarding_submit_name_path, params: { first_name: "Alex", hangout_name: "Friday Night" }
    post onboarding_submit_date_path, params: { date: 1.week.from_now.to_date.to_s }
    post onboarding_submit_cadence_path, params: { cadence: "yearly" }
    assert_response :unprocessable_entity
    assert_match /how often/i, flash[:error]
  end

  test "submit_cadence with none cadence still creates occurrence" do
    assert_difference "EventOccurrence.count", 1 do
      complete_cadence_step(cadence: "none")
    end
  end

  test "submit_cadence with monthly cadence creates occurrence" do
    assert_difference "EventOccurrence.count", 1 do
      complete_cadence_step(cadence: "monthly")
    end
  end

  # ---- GET /onboarding/phone ----

  test "phone renders step 4 when occurrence_id is in session" do
    complete_cadence_step
    get onboarding_phone_path
    assert_response :success
  end

  test "phone redirects to splash when no occurrence_id in session" do
    get onboarding_phone_path
    assert_redirected_to onboarding_splash_path
  end

  test "phone redirects to dashboard when user is already phone-verified" do
    user = create_user(phone_number: "5551234567", phone_verified_at: Time.current)
    sign_in(user)
    get onboarding_phone_path
    assert_redirected_to dashboard_path
  end

  # ---- POST /onboarding/phone ----

  test "submit_phone with valid number redirects to verify" do
    complete_cadence_step
    SmsService.stub(:send_message, true) do
      post onboarding_submit_phone_path, params: { phone: "5559876543" }
    end
    assert_redirected_to onboarding_verify_path
  end

  test "submit_phone with short number re-renders with error" do
    complete_cadence_step
    post onboarding_submit_phone_path, params: { phone: "123" }
    assert_response :unprocessable_entity
    assert_match /valid 10-digit/i, flash[:error]
  end

  test "submit_phone writes OTP to cache even if SMS raises" do
    complete_cadence_step
    with_memory_cache do
      SmsService.stub(:send_message, ->(to:, body:) { raise "Twilio down" }) do
        post onboarding_submit_phone_path, params: { phone: "5559876543" }
      end
      assert_redirected_to onboarding_verify_path
      assert Rails.cache.read("otp:5559876543").present?
    end
  end

  # ---- GET /onboarding/verify ----

  test "verify renders step 5 when ob_phone is in session" do
    complete_cadence_step
    SmsService.stub(:send_message, true) do
      post onboarding_submit_phone_path, params: { phone: "5559876543" }
    end
    get onboarding_verify_path
    assert_response :success
  end

  test "verify redirects to phone when no ob_phone in session" do
    get onboarding_verify_path
    assert_redirected_to onboarding_phone_path
  end

  # ---- POST /onboarding/verify ----

  test "submit_verify with correct code updates user phone and redirects to invite" do
    complete_cadence_step
    with_memory_cache do
      SmsService.stub(:send_message, true) do
        post onboarding_submit_phone_path, params: { phone: "5559876543" }
      end
      Rails.cache.write("otp:5559876543", "111222", expires_in: 10.minutes)
      post onboarding_submit_verify_path, params: { code: "111222" }
    end
    assert_redirected_to onboarding_invite_path
    assert User.find_by(phone_number: "5559876543")&.phone_verified_at.present?
  end

  test "submit_verify with wrong code re-renders with error" do
    complete_cadence_step
    with_memory_cache do
      SmsService.stub(:send_message, true) do
        post onboarding_submit_phone_path, params: { phone: "5559876543" }
      end
      Rails.cache.write("otp:5559876543", "999999", expires_in: 10.minutes)
      post onboarding_submit_verify_path, params: { code: "000000" }
    end
    assert_response :unprocessable_entity
    assert_match /didn't match/i, flash[:error]
  end

  test "submit_verify with expired OTP re-renders with error" do
    complete_cadence_step
    with_memory_cache do
      SmsService.stub(:send_message, true) do
        post onboarding_submit_phone_path, params: { phone: "5559876543" }
      end
      Rails.cache.delete("otp:5559876543")
      post onboarding_submit_verify_path, params: { code: "123456" }
    end
    assert_response :unprocessable_entity
    assert_match /didn't match/i, flash[:error]
  end

  # ---- POST /onboarding/resend ----

  test "resend_otp redirects to verify with notice" do
    complete_cadence_step
    SmsService.stub(:send_message, true) do
      post onboarding_submit_phone_path, params: { phone: "5559876543" }
      post onboarding_resend_otp_path
    end
    assert_redirected_to onboarding_verify_path
    assert_match /resent/i, flash[:notice]
  end

  test "resend_otp redirects to phone step when no ob_phone in session" do
    post onboarding_resend_otp_path
    assert_redirected_to onboarding_phone_path
  end

  test "resend_otp continues even if SMS raises" do
    complete_cadence_step
    SmsService.stub(:send_message, true) do
      post onboarding_submit_phone_path, params: { phone: "5559876543" }
    end
    SmsService.stub(:send_message, ->(to:, body:) { raise "Twilio down" }) do
      post onboarding_resend_otp_path
    end
    assert_redirected_to onboarding_verify_path
  end

  # ---- GET /onboarding/invite ----

  test "invite renders with hangout details when session is complete" do
    complete_cadence_step
    with_memory_cache do
      SmsService.stub(:send_message, true) do
        post onboarding_submit_phone_path, params: { phone: "5559876543" }
      end
      Rails.cache.write("otp:5559876543", "111222", expires_in: 10.minutes)
      post onboarding_submit_verify_path, params: { code: "111222" }
    end
    get onboarding_invite_path
    assert_response :success
  end

  test "invite redirects to splash when no occurrence_id in session" do
    get onboarding_invite_path
    assert_redirected_to onboarding_splash_path
  end
end
