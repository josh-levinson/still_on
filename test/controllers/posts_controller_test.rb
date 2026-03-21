require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user  = create_user(first_name: "Dashboard", last_name: "User")
    @group = create_group(@user, name: "My Test Group")
    GroupMembership.create!(group: @group, user: @user, role: "organizer")
    @event = create_event(@group, @user)
  end

  # ---- GET /dashboard ----

  test "dashboard redirects to sign-in when not authenticated" do
    get dashboard_path
    assert_redirected_to onboarding_splash_path
  end

  test "dashboard renders successfully when signed in" do
    sign_in(@user)
    get dashboard_path
    assert_response :success
  end

  test "dashboard shows the current user's name" do
    sign_in(@user)
    get dashboard_path
    assert_match "Dashboard User", response.body
  end

  test "dashboard shows groups belonging to current user" do
    sign_in(@user)
    get dashboard_path
    assert_match "My Test Group", response.body
  end

  test "dashboard shows upcoming scheduled occurrences for user groups" do
    occurrence = create_occurrence(@event, start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours)
    sign_in(@user)
    get dashboard_path
    assert_match occurrence.event.title, response.body
  end

  test "dashboard does not show cancelled occurrences" do
    create_occurrence(@event, start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours, status: "cancelled")
    # With no scheduled occurrences, the empty state message appears
    sign_in(@user)
    get dashboard_path
    assert_match "No upcoming events", response.body
  end

  test "dashboard does not show occurrences from groups the user does not belong to" do
    other_user  = create_user
    other_group = create_group(other_user, name: "Other Group That Should Be Hidden")
    other_event = create_event(other_group, other_user)
    create_occurrence(other_event, start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours)

    sign_in(@user)
    get dashboard_path
    assert_no_match "Other Group That Should Be Hidden", response.body
  end

  test "dashboard shows empty state when user has no upcoming events" do
    sign_in(@user)
    get dashboard_path
    assert_match "No upcoming events", response.body
  end

  test "dashboard shows multiple groups" do
    group_b = create_group(@user, name: "Group B")
    GroupMembership.create!(group: group_b, user: @user, role: "member")
    sign_in(@user)
    get dashboard_path
    assert_match "My Test Group", response.body
    assert_match "Group B", response.body
  end
end
