require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user  = create_user(first_name: "Dana", last_name: "User")
    @group = create_group(@user, name: "Friday Poker")
    GroupMembership.create!(group: @group, user: @user, role: "organizer")
    @event = create_event(@group, @user, title: "Friday Poker")
  end

  def organize_section
    css_select(".dashboard-section").find { |s| s.text.include?("You organize") }
  end

  def attend_section
    css_select(".dashboard-section").find { |s| s.text.include?("You're in") }
  end

  test "redirects to sign-in when not authenticated" do
    get dashboard_path
    assert_redirected_to onboarding_splash_path
  end

  test "greets the user by first name" do
    sign_in(@user)
    get dashboard_path
    assert_response :success
    assert_match "Hi, Dana", response.body
  end

  test "falls back to full name when there's no first name" do
    @user.update!(first_name: nil)
    sign_in(@user)
    get dashboard_path
    assert_match "Hi, User", response.body
  end

  test "shows an empty state when the user has no hangouts" do
    sign_in(create_user)
    get dashboard_path
    assert_match "You don't have any hangouts yet", response.body
    assert_select ".dashboard-section", count: 0
  end

  # ---- You organize ----

  test "lists hangouts the user created under You organize" do
    occurrence = create_occurrence(@event, start_time: Time.zone.parse("2030-10-04 19:00"), end_time: Time.zone.parse("2030-10-04 21:00"))
    sign_in(@user)
    get dashboard_path
    assert_includes organize_section.text, "Friday Poker"
    assert_includes organize_section.text, "Weekly"
    assert_includes organize_section.text, occurrence.start_time.in_time_zone(@group.time_zone).strftime("%a %b %-d")
    assert_nil attend_section
  end

  test "lists hangouts where the user is a co-organizer" do
    owner = create_user
    group = create_group(owner, name: "Book Club")
    GroupMembership.create!(group: group, user: @user, role: "organizer")
    sign_in(@user)
    get dashboard_path
    assert_includes organize_section.text, "Book Club"
  end

  test "organizer card shows the RSVP tally and a nudge button" do
    occurrence = create_occurrence(@event)
    create_rsvp(occurrence, status: "attending", guest_count: 1)
    create_rsvp(occurrence, status: "maybe")
    GuestGroupSubscription.subscribe(group: @group, phone_number: "+15550001111")

    sign_in(@user)
    get dashboard_path
    assert_includes organize_section.text, "2 in"
    assert_includes organize_section.text, "1 maybe"
    assert_includes organize_section.text, "2 no reply"
    assert_select "form[action=?] button", send_rsvp_reminder_group_event_event_occurrence_path(@group.slug, @event, occurrence), text: "Nudge 2"
    assert_select "[data-clipboard-target=source]", text: guest_rsvp_url(occurrence.invite_token)
  end

  test "organizer card hides the nudge button when everyone has replied" do
    occurrence = create_occurrence(@event)
    create_rsvp(occurrence, user: @user, guest_name: nil)
    sign_in(@user)
    get dashboard_path
    assert_includes organize_section.text, "0 no reply"
    assert_select "button", text: /Nudge/, count: 0
  end

  test "organizer card shows the event title when it differs from the group name" do
    event = create_event(@group, @user, title: "Tournament Night", recurrence_type: "none")
    create_occurrence(event)
    sign_in(@user)
    get dashboard_path
    assert_includes organize_section.text, "Tournament Night"
    assert_includes organize_section.text, "One-time"
  end

  test "organizer card warns when the next date is below quorum" do
    @event.update!(quorum: 4)
    occurrence = create_occurrence(@event)
    create_rsvp(occurrence, status: "attending")
    sign_in(@user)
    get dashboard_path
    assert_includes organize_section.text, "Needs 3 more to happen"
  end

  test "organizer card doesn't warn when quorum is met" do
    @event.update!(quorum: 1)
    occurrence = create_occurrence(@event)
    create_rsvp(occurrence, status: "attending")
    sign_in(@user)
    get dashboard_path
    assert_not_includes organize_section.text, "more to happen"
  end

  test "organizer card shows a paused group with its resume date" do
    create_occurrence(@event)
    @group.pause!(until_date: Date.new(2099, 11, 1))
    sign_in(@user)
    get dashboard_path
    assert_includes organize_section.text, "Paused until Nov 1"
  end

  test "organizer card shows an indefinitely paused group" do
    @group.pause!
    sign_in(@user)
    get dashboard_path
    assert_includes organize_section.text, "Paused. No reminders are going out."
  end

  test "organizer card says when nothing is scheduled" do
    create_occurrence(@event, status: "cancelled")
    sign_in(@user)
    get dashboard_path
    assert_includes organize_section.text, "Nothing scheduled"
  end

  # ---- You're in ----

  test "lists groups the user is a member of under You're in" do
    owner = create_user
    group = create_group(owner, name: "Sunday Hike")
    GroupMembership.create!(group: group, user: @user, role: "member")
    event = create_event(group, owner)
    occurrence = create_occurrence(event)

    sign_in(@user)
    get dashboard_path
    assert_includes attend_section.text, "Sunday Hike"
    assert_select "a[href=?]", guest_rsvp_path(occurrence.invite_token), text: "Sunday Hike"
    assert_not_includes organize_section.text, "Sunday Hike"
  end

  test "lists groups the user subscribed to as a guest" do
    owner = create_user
    group = create_group(owner, name: "Trivia")
    GuestGroupSubscription.subscribe(group: group, phone_number: @user.phone_number)
    sign_in(@user)
    get dashboard_path
    assert_includes attend_section.text, "Trivia"
    assert_includes attend_section.text, "No upcoming dates"
  end

  test "lists groups the user has RSVP'd to" do
    owner = create_user
    group = create_group(owner, name: "Board Games")
    occurrence = create_occurrence(create_event(group, owner))
    create_rsvp(occurrence, user: @user, guest_name: nil, status: "maybe")

    sign_in(@user)
    get dashboard_path
    assert_includes attend_section.text, "Board Games"
    rsvp = occurrence.rsvps.find_by(user: @user)
    assert_select "form[action=?] button.btn-primary", event_occurrence_rsvp_path(occurrence, rsvp), text: "Maybe"
    assert_select "form[action=?] button.btn-secondary", event_occurrence_rsvp_path(occurrence, rsvp), text: "Going"
  end

  test "attendee card offers RSVP buttons when the user hasn't replied" do
    owner = create_user
    group = create_group(owner)
    GroupMembership.create!(group: group, user: @user, role: "member")
    occurrence = create_occurrence(create_event(group, owner))

    sign_in(@user)
    get dashboard_path
    assert_select "form[action=?]", event_occurrence_rsvps_path(occurrence), count: 3
  end

  test "doesn't show groups the user has no connection to" do
    other = create_user
    group = create_group(other, name: "Someone Else's Group")
    create_occurrence(create_event(group, other))
    sign_in(@user)
    get dashboard_path
    assert_no_match "Someone Else's Group", response.body
  end
end
