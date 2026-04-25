require "test_helper"

class AccountClaimsControllerTest < ActionDispatch::IntegrationTest
  # ---- GET /claim ----

  test "new redirects to dashboard when signed in" do
    user = create_user
    sign_in(user)
    get new_account_claim_path
    assert_redirected_to dashboard_path
  end

  test "new renders when not signed in" do
    get new_account_claim_path
    assert_response :success
  end

  # ---- POST /claim ----

  test "submit_phone redirects when signed in" do
    user = create_user
    sign_in(user)
    post account_claim_submit_phone_path, params: { first_name: "Jo", phone: "5550001234" }
    assert_redirected_to dashboard_path
  end

  test "submit_phone renders error when first name is blank" do
    post account_claim_submit_phone_path, params: { first_name: "", phone: "5550001234" }
    assert_response :unprocessable_entity
    assert_match "Please enter your name", response.body
  end

  test "submit_phone renders error when phone is too short" do
    post account_claim_submit_phone_path, params: { first_name: "Jo", phone: "555" }
    assert_response :unprocessable_entity
    assert_match "valid 10-digit", response.body
  end

  test "submit_phone redirects to sign-in when phone already has an account" do
    existing = create_user(phone_number: "5550001234")
    post account_claim_submit_phone_path, params: { first_name: "Jo", phone: existing.phone_number }
    assert_redirected_to sign_in_path
    assert_match "already have an account", flash[:notice]
  end

  test "submit_phone sends OTP and redirects to verify" do
    SmsService.stub(:send_message, true) do
      post account_claim_submit_phone_path, params: { first_name: "Jo", phone: "5550009999" }
    end
    assert_redirected_to account_claim_verify_path
  end

  test "submit_phone still redirects to verify even when SMS delivery fails" do
    SmsService.stub(:send_message, ->(*) { raise "Twilio error" }) do
      post account_claim_submit_phone_path, params: { first_name: "Jo", phone: "5550009999" }
    end
    assert_redirected_to account_claim_verify_path
  end

  # ---- GET /claim/verify ----

  test "verify redirects to new when claim_phone not in session" do
    get account_claim_verify_path
    assert_redirected_to new_account_claim_path
  end

  test "verify renders when claim_phone is in session" do
    SmsService.stub(:send_message, true) do
      post account_claim_submit_phone_path, params: { first_name: "Jo", phone: "5550009999" }
    end
    get account_claim_verify_path
    assert_response :success
  end

  # ---- POST /claim/verify ----

  test "submit_verify renders error on wrong code" do
    SmsService.stub(:send_message, true) do
      post account_claim_submit_phone_path, params: { first_name: "Jo", phone: "5550009999" }
    end
    post account_claim_submit_verify_path, params: { code: "000000" }
    assert_response :unprocessable_entity
    assert_match "That code", response.body
  end

  test "submit_verify creates user and signs in on correct code" do
    SmsService.stub(:send_message, true) do
      post account_claim_submit_phone_path, params: { first_name: "Jo", phone: "5550009999" }
    end

    otp = session[:claim_otp]
    assert_difference "User.count", 1 do
      post account_claim_submit_verify_path, params: { code: otp }
    end

    assert_redirected_to dashboard_path
    user = User.find_by(phone_number: "5550009999")
    assert user.phone_verified_at.present?
    assert_equal user.id.to_s, session[:user_id].to_s
  end

  test "submit_verify claims prior guest RSVPs matching the phone" do
    organizer   = create_user
    group       = create_group(organizer)
    event       = create_event(group, organizer)
    occurrence  = create_occurrence(event)
    rsvp        = Rsvp.create!(
      event_occurrence: occurrence,
      guest_name: "Jo",
      guest_phone: "5550009999",
      status: "attending",
      guest_count: 0
    )

    SmsService.stub(:send_message, true) do
      post account_claim_submit_phone_path, params: { first_name: "Jo", phone: "5550009999" }
    end

    otp = session[:claim_otp]
    post account_claim_submit_verify_path, params: { code: otp }

    user = User.find_by(phone_number: "5550009999")
    assert_equal user.id, rsvp.reload.user_id
    assert_nil rsvp.guest_phone
    assert_nil rsvp.guest_name
  end

  test "submit_verify sets welcome flash notice" do
    SmsService.stub(:send_message, true) do
      post account_claim_submit_phone_path, params: { first_name: "Jo", phone: "5550009999" }
    end

    otp = session[:claim_otp]
    post account_claim_submit_verify_path, params: { code: otp }
    assert_match "Welcome to StillOn", flash[:notice]
  end

  test "submit_verify does not create user when OTP is expired" do
    SmsService.stub(:send_message, true) do
      post account_claim_submit_phone_path, params: { first_name: "Jo", phone: "5550009999" }
    end

    otp = session[:claim_otp]
    travel_to 11.minutes.from_now do
      assert_no_difference "User.count" do
        post account_claim_submit_verify_path, params: { code: otp }
      end
    end
    assert_response :unprocessable_entity
  end
end
