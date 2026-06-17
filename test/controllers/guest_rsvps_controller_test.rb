require "test_helper"

class GuestRsvpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = create_user
    @group = create_group(@organizer)
    @event = create_event(@group, @organizer)
    @occurrence = create_occurrence(@event)
    @token = @occurrence.invite_token
    @phone = "+15550001234"
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

  test "show succeeds with a prefilled phone param" do
    get guest_rsvp_path(@token, p: @phone)
    assert_response :success
  end

  test "show succeeds when a matching guest RSVP already exists for the prefilled phone" do
    Rsvp.create!(event_occurrence: @occurrence, guest_name: "Phone Guest", guest_phone: @phone,
                 status: "attending", guest_count: 0)
    get guest_rsvp_path(@token, p: @phone)
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

  test "create with prefilled phone saves guest_phone" do
    post guest_rsvp_path(@token, p: @phone), params: {
      rsvp: { status: "attending", guest_name: "Phone RSVP", guest_phone: @phone, guest_count: 0 }
    }
    assert_redirected_to guest_rsvp_path(@token)
    rsvp = Rsvp.last
    assert_equal @phone, rsvp.guest_phone
  end

  # --- create (update existing) ---

  test "create updates an existing guest RSVP when phone matches" do
    existing = Rsvp.create!(event_occurrence: @occurrence, guest_name: "Phone Guest",
                            guest_phone: "+15550001234", status: "attending", guest_count: 0)

    assert_no_difference "Rsvp.count" do
      post guest_rsvp_path(@token, p: @phone), params: {
        rsvp: { status: "declined", guest_name: "Phone Guest", guest_phone: "+15550001234", guest_count: 0 }
      }
    end

    assert_redirected_to guest_rsvp_path(@token)
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

    post guest_rsvp_path(@token, p: @phone), params: {
      rsvp: { status: "invalid_status", guest_name: "Phone Guest", guest_count: 0 }
    }
    assert_response :unprocessable_entity
    assert_equal "attending", existing.reload.status
  end

  # --- send_future_reminders subscription ---

  test "create with send_future_reminders subscribes the guest to future reminders" do
    assert_difference "GuestGroupSubscription.count", 1 do
      post guest_rsvp_path(@token, p: @phone), params: {
        rsvp: { status: "attending", guest_name: "Sub Guest", guest_phone: "+15550001234", guest_count: 0 },
        send_future_reminders: "1"
      }
    end
  end

  # --- cookie fallback in find_existing_rsvp ---

  test "show uses cookie phone to find existing RSVP when token has no phone" do
    # Create RSVP with the phone that will end up in cookie
    Rsvp.create!(event_occurrence: @occurrence, guest_name: "Cookie Person",
                 guest_phone: "+15550001234", status: "attending", guest_count: 0)
    # POST with prefilled phone sets the guest_phone cookie
    post guest_rsvp_path(@token, p: @phone), params: {
      rsvp: { status: "attending", guest_name: "Cookie Person", guest_count: 0 }
    }
    # GET with base token (no phone) — finds RSVP via cookie fallback
    get guest_rsvp_path(@token)
    assert_response :success
  end

  # --- max attendees enforcement ---

  test "create blocks new attending RSVP when event is full" do
    full_occurrence = create_occurrence(@event, max_attendees: 1)
    create_rsvp(full_occurrence, guest_name: "First", guest_phone: "+15550009999", guest_count: 0)
    token = full_occurrence.invite_token

    assert_no_difference "Rsvp.count" do
      post guest_rsvp_path(token), params: {
        rsvp: { status: "attending", guest_name: "Late Guest", guest_count: 0 }
      }
    end

    assert_redirected_to guest_rsvp_path(token)
    assert_match /full/i, flash[:alert]
  end

  test "create allows maybe RSVP when event is full" do
    full_occurrence = create_occurrence(@event, max_attendees: 1)
    create_rsvp(full_occurrence, guest_name: "First", guest_phone: "+15550009999", guest_count: 0)
    token = full_occurrence.invite_token

    assert_difference "Rsvp.count", 1 do
      post guest_rsvp_path(token), params: {
        rsvp: { status: "maybe", guest_name: "Maybe Guest", guest_count: 0 }
      }
    end

    assert_redirected_to guest_rsvp_path(token)
  end

  test "create allows updating existing RSVP to attending when event is full" do
    full_occurrence = create_occurrence(@event, max_attendees: 1)
    phone = "+15550001234"
    create_rsvp(full_occurrence, guest_name: "First", guest_phone: phone, guest_count: 0)
    token = full_occurrence.invite_token

    assert_no_difference "Rsvp.count" do
      post guest_rsvp_path(token, p: phone), params: {
        rsvp: { status: "attending", guest_name: "First", guest_phone: phone, guest_count: 0 }
      }
    end

    assert_redirected_to guest_rsvp_path(token)
    assert flash[:alert].blank?
  end

  # --- calendar (ICS download) ---

  test "calendar returns an ICS file for a valid token" do
    get guest_rsvp_calendar_path(@token)
    assert_response :success
    assert_equal "text/calendar", response.content_type
    assert_includes response.body, "BEGIN:VCALENDAR"
    assert_includes response.body, "BEGIN:VEVENT"
    assert_includes response.body, "END:VEVENT"
    assert_includes response.body, @occurrence.id
  end

  test "calendar includes event title and occurrence times" do
    get guest_rsvp_calendar_path(@token)
    assert_includes response.body, "SUMMARY:#{@event.title}"
    assert_includes response.body, @occurrence.start_time.utc.strftime("%Y%m%dT%H%M%SZ")
    assert_includes response.body, @occurrence.end_time.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  test "calendar includes location when present" do
    @occurrence.update!(location: "Central Park")
    get guest_rsvp_calendar_path(@token)
    assert_includes response.body, "LOCATION:Central Park"
  end

  test "calendar includes notes in description when present" do
    @occurrence.update!(notes: "Bring snacks")
    get guest_rsvp_calendar_path(@token)
    assert_includes response.body, "DESCRIPTION:Bring snacks"
  end

  test "calendar omits description when notes are blank" do
    @occurrence.update!(notes: nil)
    get guest_rsvp_calendar_path(@token)
    assert_not_includes response.body, "DESCRIPTION:"
  end

  test "calendar returns 404 for an invalid token" do
    get guest_rsvp_calendar_path("bad-token")
    assert_response :not_found
  end

  # --- rsvp_confirmation_message: implicit else branch ---

  test "rsvp_confirmation_message returns nil for unrecognized status" do
    ctrl = GuestRsvpsController.new
    rsvp = Struct.new(:status).new("unknown")
    assert_nil ctrl.send(:rsvp_confirmation_message, rsvp)
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
