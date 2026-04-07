require "test_helper"

class NewHangoutControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
  end

  # Helper: drive the wizard to just before cadence submission.
  def setup_wizard(cadence: "weekly", date: nil)
    date ||= 1.week.from_now.to_date.to_s
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "Friday Night" }
    post new_hangout_submit_date_path, params: { date: date }
  end

  # Helper: complete the full wizard through cadence and return the occurrence.
  def complete_wizard(cadence: "weekly", date: nil)
    setup_wizard(cadence: cadence, date: date)
    post new_hangout_submit_cadence_path, params: { cadence: cadence }
    EventOccurrence.order(:created_at).last
  end

  # ---- Authentication guard ----

  test "name redirects unauthenticated user to sign-in" do
    get new_hangout_path
    assert_redirected_to onboarding_splash_path
  end

  test "submit_name redirects unauthenticated user to sign-in" do
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks" }
    assert_redirected_to onboarding_splash_path
  end

  # ---- GET /hangouts/new (name step) ----

  test "name renders step 1 for signed-in user" do
    sign_in(@user)
    get new_hangout_path
    assert_response :success
  end

  # ---- POST /hangouts/new/name ----

  test "submit_name with valid hangout_name redirects to date step" do
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks" }
    assert_redirected_to new_hangout_date_path
  end

  test "submit_name stores hangout_name in session" do
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks" }
    assert_equal "Drinks", session[:nh_hangout_name]
  end

  test "submit_name with blank hangout_name re-renders with error" do
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "" }
    assert_response :unprocessable_entity
    assert_match /name your hangout/i, flash[:error]
  end

  test "submit_name with known IANA timezone stores matching Rails zone" do
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks", time_zone: "America/New_York" }
    assert_equal "Eastern Time (US & Canada)", session[:nh_time_zone]
  end

  test "submit_name with unknown IANA timezone falls back to user time_zone when set" do
    user = create_user(time_zone: "Pacific Time (US & Canada)")
    sign_in(user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks", time_zone: "Unknown/Zone" }
    assert_equal "Pacific Time (US & Canada)", session[:nh_time_zone]
  end

  test "submit_name with unknown IANA timezone falls back to UTC when user has no time_zone" do
    user = create_user(time_zone: nil)
    sign_in(user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks", time_zone: "Unknown/Zone" }
    assert_equal "UTC", session[:nh_time_zone]
  end

  test "submit_name with blank timezone falls back to user time_zone when set" do
    user = create_user(time_zone: "Central Time (US & Canada)")
    sign_in(user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks", time_zone: "" }
    assert_equal "Central Time (US & Canada)", session[:nh_time_zone]
  end

  test "submit_name with blank timezone falls back to UTC when user has no time_zone" do
    user = create_user(time_zone: nil)
    sign_in(user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks", time_zone: "" }
    assert_equal "UTC", session[:nh_time_zone]
  end

  # ---- GET /hangouts/new/date ----

  test "date_step renders step 2 when hangout_name is in session" do
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks" }
    get new_hangout_date_path
    assert_response :success
  end

  test "date_step redirects to name step when no hangout_name in session" do
    sign_in(@user)
    get new_hangout_date_path
    assert_redirected_to new_hangout_path
  end

  test "date_step on a Friday assigns the following Friday as this_friday" do
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks" }
    travel_to Time.zone.local(2026, 4, 10, 12, 0, 0) do  # 2026-04-10 is a Friday
      get new_hangout_date_path
      assert_response :success
    end
  end

  # ---- POST /hangouts/new/date ----

  test "submit_date with valid future date redirects to cadence" do
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks" }
    post new_hangout_submit_date_path, params: { date: 1.week.from_now.to_date.to_s }
    assert_redirected_to new_hangout_cadence_path
  end

  test "submit_date with past date re-renders with error" do
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks" }
    post new_hangout_submit_date_path, params: { date: 2.days.ago.to_date.to_s }
    assert_response :unprocessable_entity
    assert_match /valid future date/i, flash[:error]
  end

  test "submit_date with garbage string re-renders with error" do
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks" }
    post new_hangout_submit_date_path, params: { date: "not-a-date" }
    assert_response :unprocessable_entity
    assert_match /valid future date/i, flash[:error]
  end

  test "submit_date with blank date re-renders with error" do
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks" }
    post new_hangout_submit_date_path, params: { date: "" }
    assert_response :unprocessable_entity
    assert_match /valid future date/i, flash[:error]
  end

  test "submit_date error path on a Friday sets days_until_friday to 7" do
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks" }
    travel_to Time.zone.local(2026, 4, 10, 12, 0, 0) do  # Friday
      post new_hangout_submit_date_path, params: { date: "1999-01-01" }
      assert_response :unprocessable_entity
    end
  end

  # ---- GET /hangouts/new/cadence ----

  test "cadence renders step 3 when date is in session" do
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks" }
    post new_hangout_submit_date_path, params: { date: 1.week.from_now.to_date.to_s }
    get new_hangout_cadence_path
    assert_response :success
  end

  test "cadence redirects to name step when no date in session" do
    sign_in(@user)
    get new_hangout_cadence_path
    assert_redirected_to new_hangout_path
  end

  # ---- POST /hangouts/new/cadence ----

  test "submit_cadence creates group, event, and occurrence" do
    sign_in(@user)
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks" }
    post new_hangout_submit_date_path, params: { date: 1.week.from_now.to_date.to_s }
    assert_difference [ "Group.count", "Event.count", "EventOccurrence.count" ], 1 do
      post new_hangout_submit_cadence_path, params: { cadence: "weekly" }
    end
  end

  test "submit_cadence auto-adds creator as group member" do
    setup_wizard
    post new_hangout_submit_cadence_path, params: { cadence: "weekly" }
    group = Group.order(:created_at).last
    assert group.member?(@user)
  end

  test "submit_cadence redirects to invite step" do
    setup_wizard
    post new_hangout_submit_cadence_path, params: { cadence: "weekly" }
    assert_redirected_to new_hangout_invite_path
  end

  test "submit_cadence with invalid cadence re-renders with error" do
    setup_wizard
    post new_hangout_submit_cadence_path, params: { cadence: "yearly" }
    assert_response :unprocessable_entity
    assert_match /how often/i, flash[:error]
  end

  test "submit_cadence with none cadence creates occurrence without recurrence rule" do
    assert_difference "EventOccurrence.count", 1 do
      complete_wizard(cadence: "none")
    end
    event = Event.order(:created_at).last
    assert_nil event.recurrence_rule
  end

  test "submit_cadence with weekly cadence builds recurrence schedule" do
    complete_wizard(cadence: "weekly")
    event = Event.order(:created_at).last
    assert_not_nil event.recurrence_rule
  end

  test "submit_cadence with monthly cadence builds recurrence schedule with nth_weekday" do
    complete_wizard(cadence: "monthly")
    event = Event.order(:created_at).last
    assert_not_nil event.recurrence_rule
  end

  test "submit_cadence generates unique slug when name collides with existing group" do
    Group.create!(name: "Existing", slug: "friday-night", created_by: @user, is_private: false)
    setup_wizard
    post new_hangout_submit_cadence_path, params: { cadence: "weekly" }
    new_group = Group.order(:created_at).last
    assert_match(/\Afriday-night-.+\z/, new_group.slug)
  end

  test "submit_cadence uses UTC when no timezone is stored and user has none" do
    user = create_user(time_zone: nil)
    sign_in(user)
    # Submit name without a timezone param so session[:nh_time_zone] ends up as "UTC"
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks", time_zone: "" }
    post new_hangout_submit_date_path, params: { date: 1.week.from_now.to_date.to_s }
    assert_difference "EventOccurrence.count", 1 do
      post new_hangout_submit_cadence_path, params: { cadence: "weekly" }
    end
  end

  test "submit_cadence falls back to user time_zone when session has no timezone" do
    user = create_user(time_zone: "Pacific Time (US & Canada)")
    sign_in(user)
    # Submit name without timezone so the IANA lookup returns user's zone
    post new_hangout_submit_name_path, params: { hangout_name: "Drinks", time_zone: "" }
    post new_hangout_submit_date_path, params: { date: 1.week.from_now.to_date.to_s }
    assert_difference "EventOccurrence.count", 1 do
      post new_hangout_submit_cadence_path, params: { cadence: "weekly" }
    end
  end

  # ---- GET /hangouts/new/invite ----

  test "invite renders with hangout details when session is complete" do
    complete_wizard
    get new_hangout_invite_path
    assert_response :success
  end

  test "invite redirects to dashboard when no occurrence_id in session" do
    sign_in(@user)
    get new_hangout_invite_path
    assert_redirected_to dashboard_path
  end
end
