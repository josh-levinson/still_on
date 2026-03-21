require "test_helper"

class RsvpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organizer  = create_user
    @other      = create_user
    @group      = create_group(@organizer)
    @event      = create_event(@group, @organizer)
    @occurrence = create_occurrence(@event)
    @rsvp       = create_rsvp(@occurrence, user: @organizer, status: "attending")
  end

  def occurrence_path_for(occurrence)
    group_event_event_occurrence_path(
      occurrence.event.group.slug,
      occurrence.event,
      occurrence
    )
  end

  # ---- POST /event_occurrences/:event_occurrence_id/rsvps (create) ----

  test "create requires sign-in" do
    post event_occurrence_rsvps_path(@occurrence), params: { rsvp: { status: "attending", guest_count: 0 } }
    assert_redirected_to onboarding_splash_path
  end

  test "create saves an RSVP and redirects to occurrence show" do
    sign_in(@other)
    assert_difference "Rsvp.count", 1 do
      post event_occurrence_rsvps_path(@occurrence), params: { rsvp: { status: "attending", guest_count: 0 } }
    end
    assert_redirected_to occurrence_path_for(@occurrence)
    assert_match /successfully created/i, flash[:notice]
  end

  test "create sets current_user on the new RSVP" do
    sign_in(@other)
    post event_occurrence_rsvps_path(@occurrence), params: { rsvp: { status: "attending", guest_count: 0 } }
    assert_equal @other, Rsvp.order(:created_at).last.user
  end

  test "create redirects with alert on invalid params" do
    sign_in(@other)
    assert_no_difference "Rsvp.count" do
      post event_occurrence_rsvps_path(@occurrence), params: { rsvp: { status: "", guest_count: 0 } }
    end
    assert_redirected_to occurrence_path_for(@occurrence)
    assert flash[:alert].present?
  end

  # ---- PATCH /event_occurrences/:event_occurrence_id/rsvps/:id (update) ----

  test "update requires sign-in" do
    patch event_occurrence_rsvp_path(@occurrence, @rsvp), params: { rsvp: { status: "maybe" } }
    assert_redirected_to onboarding_splash_path
  end

  test "update saves changes and redirects to occurrence show" do
    sign_in(@organizer)
    patch event_occurrence_rsvp_path(@occurrence, @rsvp), params: { rsvp: { status: "maybe" } }
    assert_redirected_to occurrence_path_for(@occurrence)
    assert_match /successfully updated/i, flash[:notice]
    assert_equal "maybe", @rsvp.reload.status
  end

  test "update re-renders edit with unprocessable_entity on invalid params" do
    sign_in(@organizer)
    patch event_occurrence_rsvp_path(@occurrence, @rsvp), params: { rsvp: { status: "bad_status" } }
    assert_response :unprocessable_entity
  end

  test "update is forbidden for a non-owner" do
    sign_in(@other)
    patch event_occurrence_rsvp_path(@occurrence, @rsvp), params: { rsvp: { status: "maybe" } }
    assert_redirected_to occurrence_path_for(@occurrence)
    assert_match /not authorized/i, flash[:alert]
    assert_equal "attending", @rsvp.reload.status
  end

  # ---- DELETE /event_occurrences/:event_occurrence_id/rsvps/:id (destroy) ----

  test "destroy requires sign-in" do
    delete event_occurrence_rsvp_path(@occurrence, @rsvp)
    assert_redirected_to onboarding_splash_path
  end

  test "destroy deletes the RSVP and redirects to occurrence show" do
    sign_in(@organizer)
    assert_difference "Rsvp.count", -1 do
      delete event_occurrence_rsvp_path(@occurrence, @rsvp)
    end
    assert_redirected_to occurrence_path_for(@occurrence)
    assert_match /successfully deleted/i, flash[:notice]
  end

  test "destroy is forbidden for a non-owner" do
    sign_in(@other)
    assert_no_difference "Rsvp.count" do
      delete event_occurrence_rsvp_path(@occurrence, @rsvp)
    end
    assert_redirected_to occurrence_path_for(@occurrence)
    assert_match /not authorized/i, flash[:alert]
  end
end
