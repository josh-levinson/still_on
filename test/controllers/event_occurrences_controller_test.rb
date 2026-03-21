require "test_helper"

class EventOccurrencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organizer  = create_user
    @other      = create_user
    @group      = create_group(@organizer)
    @event      = create_event(@group, @organizer)
    @occurrence = create_occurrence(@event)
  end

  def valid_occurrence_params
    {
      start_time: 2.weeks.from_now.iso8601,
      end_time:   (2.weeks.from_now + 2.hours).iso8601,
      status:     "scheduled"
    }
  end

  # ---- GET /groups/:group_slug/events/:event_id/event_occurrences (index) ----

  test "index requires sign-in" do
    get group_event_event_occurrences_path(@group, @event)
    assert_redirected_to onboarding_splash_path
  end

  test "index renders for signed-in user" do
    sign_in(@organizer)
    get group_event_event_occurrences_path(@group, @event)
    assert_response :success
  end

  test "index renders for non-organizer" do
    sign_in(@other)
    get group_event_event_occurrences_path(@group, @event)
    assert_response :success
  end

  # ---- GET /groups/:group_slug/events/:event_id/event_occurrences/:id (show) ----

  test "show requires sign-in" do
    get group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_redirected_to onboarding_splash_path
  end

  test "show renders for signed-in user" do
    sign_in(@organizer)
    get group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_response :success
  end

  test "show renders for non-organizer" do
    sign_in(@other)
    get group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_response :success
  end

  # ---- GET /groups/:group_slug/events/:event_id/event_occurrences/new ----

  test "new requires sign-in" do
    get new_group_event_event_occurrence_path(@group, @event)
    assert_redirected_to onboarding_splash_path
  end

  test "new renders for signed-in user" do
    sign_in(@organizer)
    get new_group_event_event_occurrence_path(@group, @event)
    assert_response :success
  end

  # ---- POST /groups/:group_slug/events/:event_id/event_occurrences (create) ----

  test "create requires sign-in" do
    post group_event_event_occurrences_path(@group, @event), params: { event_occurrence: valid_occurrence_params }
    assert_redirected_to onboarding_splash_path
  end

  test "create saves occurrence and redirects" do
    sign_in(@organizer)
    assert_difference "EventOccurrence.count", 1 do
      post group_event_event_occurrences_path(@group, @event), params: { event_occurrence: valid_occurrence_params }
    end
    occurrence = EventOccurrence.order(:created_at).last
    assert_redirected_to group_event_event_occurrence_path(@group, @event, occurrence)
    assert_match /successfully created/i, flash[:notice]
  end

  test "create re-renders new on invalid params" do
    sign_in(@organizer)
    assert_no_difference "EventOccurrence.count" do
      post group_event_event_occurrences_path(@group, @event), params: { event_occurrence: { start_time: "", end_time: "" } }
    end
    assert_response :unprocessable_entity
  end

  # ---- GET /groups/:group_slug/events/:event_id/event_occurrences/:id/edit ----

  test "edit requires sign-in" do
    get edit_group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_redirected_to onboarding_splash_path
  end

  test "edit renders for organizer" do
    sign_in(@organizer)
    get edit_group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_response :success
  end

  test "edit is forbidden for non-organizer" do
    sign_in(@other)
    get edit_group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_redirected_to group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_match /not authorized/i, flash[:alert]
  end

  # ---- PATCH /groups/:group_slug/events/:event_id/event_occurrences/:id (update) ----

  test "update requires sign-in" do
    patch group_event_event_occurrence_path(@group, @event, @occurrence), params: { event_occurrence: { location: "New Place" } }
    assert_redirected_to onboarding_splash_path
  end

  test "update saves changes and redirects for organizer" do
    sign_in(@organizer)
    patch group_event_event_occurrence_path(@group, @event, @occurrence), params: { event_occurrence: { location: "New Place" } }
    assert_redirected_to group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_match /successfully updated/i, flash[:notice]
    assert_equal "New Place", @occurrence.reload.location
  end

  test "update re-renders edit on invalid params" do
    sign_in(@organizer)
    patch group_event_event_occurrence_path(@group, @event, @occurrence), params: { event_occurrence: { status: "not_a_valid_status" } }
    assert_response :unprocessable_entity
  end

  test "update is forbidden for non-organizer" do
    sign_in(@other)
    patch group_event_event_occurrence_path(@group, @event, @occurrence), params: { event_occurrence: { location: "Hacked" } }
    assert_redirected_to group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_match /not authorized/i, flash[:alert]
    assert_not_equal "Hacked", @occurrence.reload.location
  end

  test "update enqueues cancellation job when status changes to cancelled" do
    sign_in(@organizer)
    assert_enqueued_with(job: SendCancellationNotificationJob, args: [ @occurrence.id ]) do
      patch group_event_event_occurrence_path(@group, @event, @occurrence),
        params: { event_occurrence: { status: "cancelled" } }
    end
  end

  test "update enqueues change notification job when location changes" do
    sign_in(@organizer)
    assert_enqueued_with(job: SendEventChangeNotificationJob) do
      patch group_event_event_occurrence_path(@group, @event, @occurrence),
        params: { event_occurrence: { location: "New Venue" } }
    end
  end

  test "update does not enqueue change notification when only an untracked field changes" do
    sign_in(@organizer)
    assert_no_enqueued_jobs only: SendEventChangeNotificationJob do
      patch group_event_event_occurrence_path(@group, @event, @occurrence),
        params: { event_occurrence: { notes: "Just a note" } }
    end
  end

  # ---- PATCH /groups/:group_slug/events/:event_id/event_occurrences/:id/cancel ----

  test "cancel requires sign-in" do
    patch cancel_group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_redirected_to onboarding_splash_path
  end

  test "cancel marks scheduled occurrence as cancelled and enqueues notification" do
    sign_in(@organizer)
    assert_enqueued_with(job: SendCancellationNotificationJob, args: [ @occurrence.id ]) do
      patch cancel_group_event_event_occurrence_path(@group, @event, @occurrence)
    end
    assert_equal "cancelled", @occurrence.reload.status
    assert_redirected_to group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_match /cancelled/i, flash[:notice]
  end

  test "cancel alerts when occurrence is not scheduled" do
    @occurrence.update!(status: "cancelled")
    sign_in(@organizer)
    assert_no_enqueued_jobs only: SendCancellationNotificationJob do
      patch cancel_group_event_event_occurrence_path(@group, @event, @occurrence)
    end
    assert_redirected_to group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_match /not scheduled/i, flash[:alert]
  end

  test "cancel is forbidden for non-organizer" do
    sign_in(@other)
    patch cancel_group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_redirected_to group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_match /not authorized/i, flash[:alert]
    assert_equal "scheduled", @occurrence.reload.status
  end

  # ---- DELETE /groups/:group_slug/events/:event_id/event_occurrences/:id (destroy) ----

  test "destroy requires sign-in" do
    delete group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_redirected_to onboarding_splash_path
  end

  test "destroy deletes occurrence and redirects for organizer" do
    sign_in(@organizer)
    assert_difference "EventOccurrence.count", -1 do
      delete group_event_event_occurrence_path(@group, @event, @occurrence)
    end
    assert_redirected_to group_event_event_occurrences_url(@group, @event)
    assert_match /successfully deleted/i, flash[:notice]
  end

  test "destroy is forbidden for non-organizer" do
    sign_in(@other)
    assert_no_difference "EventOccurrence.count" do
      delete group_event_event_occurrence_path(@group, @event, @occurrence)
    end
    assert_redirected_to group_event_event_occurrence_path(@group, @event, @occurrence)
    assert_match /not authorized/i, flash[:alert]
  end
end
