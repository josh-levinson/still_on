require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = create_user
    @member    = create_user
    @other     = create_user
    @group     = create_group(@organizer)
    GroupMembership.create!(group: @group, user: @organizer)
    GroupMembership.create!(group: @group, user: @member)
    @event = create_event(@group, @organizer)
  end

  # ---- GET /groups/:group_slug/events (index) ----

  test "index requires sign-in" do
    get group_events_path(@group)
    assert_redirected_to onboarding_splash_path
  end

  test "index renders for signed-in user" do
    sign_in(@organizer)
    get group_events_path(@group)
    assert_response :success
  end

  test "index renders for non-organizer member" do
    sign_in(@member)
    get group_events_path(@group)
    assert_response :success
  end

  # ---- GET /groups/:group_slug/events/:id (show) ----

  test "show requires sign-in" do
    get group_event_path(@group, @event)
    assert_redirected_to onboarding_splash_path
  end

  test "show renders for organizer" do
    sign_in(@organizer)
    get group_event_path(@group, @event)
    assert_response :success
  end

  test "show renders for non-organizer member" do
    sign_in(@member)
    get group_event_path(@group, @event)
    assert_response :success
  end

  # ---- GET /groups/:group_slug/events/new ----

  test "new requires sign-in" do
    get new_group_event_path(@group)
    assert_redirected_to onboarding_splash_path
  end

  test "new renders for signed-in user" do
    sign_in(@organizer)
    get new_group_event_path(@group)
    assert_response :success
  end

  # ---- POST /groups/:group_slug/events (create) ----

  test "create requires sign-in" do
    post group_events_path(@group), params: { event: { title: "New Event", recurrence_type: "weekly" } }
    assert_redirected_to onboarding_splash_path
  end

  test "create saves event and redirects for signed-in user" do
    sign_in(@organizer)
    assert_difference "Event.count", 1 do
      post group_events_path(@group), params: { event: { title: "New Event", recurrence_type: "weekly" } }
    end
    event = Event.order(:created_at).last
    assert_redirected_to group_event_path(@group, event)
    assert_match /successfully created/i, flash[:notice]
  end

  test "create assigns current user as creator" do
    sign_in(@organizer)
    post group_events_path(@group), params: { event: { title: "New Event", recurrence_type: "weekly" } }
    assert_equal @organizer, Event.order(:created_at).last.created_by
  end

  test "create re-renders new on invalid params" do
    sign_in(@organizer)
    assert_no_difference "Event.count" do
      post group_events_path(@group), params: { event: { title: "", recurrence_type: "weekly" } }
    end
    assert_response :unprocessable_entity
  end

  # ---- GET /groups/:group_slug/events/:id/edit ----

  test "edit requires sign-in" do
    get edit_group_event_path(@group, @event)
    assert_redirected_to onboarding_splash_path
  end

  test "edit renders for organizer" do
    sign_in(@organizer)
    get edit_group_event_path(@group, @event)
    assert_response :success
  end

  test "edit is forbidden for non-organizer" do
    sign_in(@other)
    get edit_group_event_path(@group, @event)
    assert_redirected_to group_event_path(@group, @event)
    assert_match /not authorized/i, flash[:alert]
  end

  # ---- PATCH /groups/:group_slug/events/:id (update) ----

  test "update requires sign-in" do
    patch group_event_path(@group, @event), params: { event: { title: "Updated" } }
    assert_redirected_to onboarding_splash_path
  end

  test "update saves changes and redirects for organizer" do
    sign_in(@organizer)
    patch group_event_path(@group, @event), params: { event: { title: "Renamed Event" } }
    assert_redirected_to group_event_path(@group, @event)
    assert_match /successfully updated/i, flash[:notice]
    assert_equal "Renamed Event", @event.reload.title
  end

  test "update re-renders edit on invalid params" do
    sign_in(@organizer)
    patch group_event_path(@group, @event), params: { event: { title: "" } }
    assert_response :unprocessable_entity
  end

  test "update is forbidden for non-organizer" do
    sign_in(@other)
    patch group_event_path(@group, @event), params: { event: { title: "Hacked" } }
    assert_redirected_to group_event_path(@group, @event)
    assert_match /not authorized/i, flash[:alert]
    assert_not_equal "Hacked", @event.reload.title
  end

  # ---- DELETE /groups/:group_slug/events/:id (destroy) ----

  test "destroy requires sign-in" do
    delete group_event_path(@group, @event)
    assert_redirected_to onboarding_splash_path
  end

  test "destroy deletes event and redirects for organizer" do
    sign_in(@organizer)
    assert_difference "Event.count", -1 do
      delete group_event_path(@group, @event)
    end
    assert_redirected_to group_events_url(@group)
    assert_match /successfully deleted/i, flash[:notice]
  end

  test "destroy is forbidden for non-organizer" do
    sign_in(@other)
    assert_no_difference "Event.count" do
      delete group_event_path(@group, @event)
    end
    assert_redirected_to group_event_path(@group, @event)
    assert_match /not authorized/i, flash[:alert]
  end
end
