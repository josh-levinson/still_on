require "test_helper"

class GuestRsvpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = create_user
    @group = create_group(@organizer)
    @event = create_event(@group, @organizer)
    @occurrence = create_occurrence(@event)
    @token = @occurrence.invite_token
    @phone_token = @occurrence.invite_token(phone: "+15550001234")
  end

  # --- show ---

  test "show renders the RSVP page for a valid token" do
    get guest_rsvp_path(@token)
    assert_response :success
  end

  test "show returns 404 for an invalid token" do
    get guest_rsvp_path("garbage-token")
    assert_response :not_found
  end

  test "show returns 404 for an empty token" do
    get guest_rsvp_path("x")
    assert_response :not_found
  end

  test "show succeeds with a phone-specific token" do
    get guest_rsvp_path(@phone_token)
    assert_response :success
  end

  test "show succeeds when a matching guest RSVP already exists for the phone token" do
    Rsvp.create!(event_occurrence: @occurrence, guest_name: "Phone Guest", guest_phone: "+15550001234",
                 status: "attending", guest_count: 0)
    get guest_rsvp_path(@phone_token)
    assert_response :success
  end

  test "show succeeds when a matching user RSVP already exists for signed-in user" do
    user = create_user
    sign_in(user)
    Rsvp.create!(event_occurrence: @occurrence, user: user, status: "attending", guest_count: 0)

    get guest_rsvp_path(@token)
    assert_response :success
  end

  # --- create (guest, unauthenticated) ---

  test "create saves a guest RSVP and redirects" do
    assert_difference "Rsvp.count", 1 do
      post guest_rsvp_path(@token), params: {
        rsvp: { status: "attending", guest_name: "New Guest", guest_count: 0 }
      }
    end
    assert_redirected_to guest_rsvp_path(@token)
    assert_match /you're in/i, flash[:notice]
  end

  test "create saves a declined RSVP and shows appropriate notice" do
    post guest_rsvp_path(@token), params: {
      rsvp: { status: "declined", guest_name: "Declining Guest", guest_count: 0 }
    }
    assert_redirected_to guest_rsvp_path(@token)
    assert_match /not coming/i, flash[:notice]
  end

  test "create saves a maybe RSVP and shows appropriate notice" do
    post guest_rsvp_path(@token), params: {
      rsvp: { status: "maybe", guest_name: "Maybe Guest", guest_count: 0 }
    }
    assert_redirected_to guest_rsvp_path(@token)
    assert_match /maybe/i, flash[:notice]
  end

  test "create re-renders show on invalid RSVP" do
    assert_no_difference "Rsvp.count" do
      post guest_rsvp_path(@token), params: {
        rsvp: { status: "attending", guest_name: "", guest_count: 0 }
      }
    end
    assert_response :unprocessable_entity
  end

  test "create associates RSVP with signed-in user" do
    user = create_user
    sign_in(user)

    assert_difference "Rsvp.count", 1 do
      post guest_rsvp_path(@token), params: {
        rsvp: { status: "attending", guest_count: 0 }
      }
    end

    rsvp = Rsvp.last
    assert_equal user.id, rsvp.user_id
    assert_nil rsvp.guest_name
  end

  test "create with phone token prefills guest_phone" do
    post guest_rsvp_path(@phone_token), params: {
      rsvp: { status: "attending", guest_name: "Phone RSVP", guest_phone: "+15550001234", guest_count: 0 }
    }
    assert_redirected_to guest_rsvp_path(@phone_token)
    rsvp = Rsvp.last
    assert_equal "+15550001234", rsvp.guest_phone
  end

  # --- create (update existing) ---

  test "create updates an existing guest RSVP when phone matches" do
    existing = Rsvp.create!(event_occurrence: @occurrence, guest_name: "Phone Guest",
                            guest_phone: "+15550001234", status: "attending", guest_count: 0)

    assert_no_difference "Rsvp.count" do
      post guest_rsvp_path(@phone_token), params: {
        rsvp: { status: "declined", guest_name: "Phone Guest", guest_phone: "+15550001234", guest_count: 0 }
      }
    end

    assert_redirected_to guest_rsvp_path(@phone_token)
    assert_equal "declined", existing.reload.status
  end

  test "create updates an existing user RSVP when signed in" do
    user = create_user
    sign_in(user)
    existing = Rsvp.create!(event_occurrence: @occurrence, user: user, status: "attending", guest_count: 0)

    assert_no_difference "Rsvp.count" do
      post guest_rsvp_path(@token), params: {
        rsvp: { status: "maybe", guest_count: 1 }
      }
    end

    assert_redirected_to guest_rsvp_path(@token)
    existing.reload
    assert_equal "maybe", existing.status
    assert_equal 1, existing.guest_count
  end

  test "update of existing RSVP with invalid params re-renders show" do
    existing = Rsvp.create!(event_occurrence: @occurrence, guest_name: "Phone Guest",
                            guest_phone: "+15550001234", status: "attending", guest_count: 0)

    post guest_rsvp_path(@phone_token), params: {
      rsvp: { status: "invalid_status", guest_name: "Phone Guest", guest_count: 0 }
    }
    assert_response :unprocessable_entity
    assert_equal "attending", existing.reload.status
  end

  # --- authenticated user: guest fields are stripped ---

  test "authenticated user cannot set guest_name or guest_phone" do
    user = create_user
    sign_in(user)

    post guest_rsvp_path(@token), params: {
      rsvp: { status: "attending", guest_name: "Sneaky Name", guest_phone: "+15550000000", guest_count: 0 }
    }

    rsvp = Rsvp.last
    assert_nil rsvp.guest_name
    assert_nil rsvp.guest_phone
    assert_equal user.id, rsvp.user_id
  end
end
