require "test_helper"

class GroupPausesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = create_user
    @member    = create_user
    @group     = create_group(@organizer)
    GroupMembership.create!(group: @group, user: @organizer, role: :organizer)
    GroupMembership.create!(group: @group, user: @member)
  end

  # ---- POST /groups/:group_slug/pause ----

  test "create requires sign-in" do
    post group_pause_path(@group.slug)
    assert_redirected_to onboarding_splash_path
    assert_not @group.reload.paused?
  end

  test "create is forbidden for non-organizers" do
    sign_in(@member)
    post group_pause_path(@group.slug)
    assert_redirected_to group_path(@group.slug)
    assert_match /not authorized/i, flash[:alert]
    assert_not @group.reload.paused?
  end

  test "create pauses indefinitely when no date is given" do
    sign_in(@organizer)
    post group_pause_path(@group.slug), params: { paused_until: "" }
    assert_redirected_to group_path(@group.slug)
    assert_match /until you resume/i, flash[:notice]
    assert @group.reload.paused?
    assert_nil @group.paused_until
  end

  test "create pauses until the given date" do
    sign_in(@organizer)
    resume_date = 2.weeks.from_now.to_date
    post group_pause_path(@group.slug), params: { paused_until: resume_date.iso8601 }
    assert_redirected_to group_path(@group.slug)
    assert_match resume_date.strftime("%b %-d"), flash[:notice]
    assert_equal resume_date, @group.reload.paused_until
  end

  test "create rejects a resume date that is not in the future" do
    sign_in(@organizer)
    post group_pause_path(@group.slug), params: { paused_until: 1.day.ago.to_date.iso8601 }
    assert_redirected_to group_path(@group.slug)
    assert_match /future/i, flash[:alert]
    assert_not @group.reload.paused?
  end

  # ---- DELETE /groups/:group_slug/pause ----

  test "destroy resumes a paused group" do
    @group.pause!
    sign_in(@organizer)
    delete group_pause_path(@group.slug)
    assert_redirected_to group_path(@group.slug)
    assert_match /back on/i, flash[:notice]
    assert_not @group.reload.paused?
  end

  test "destroy is forbidden for non-organizers" do
    @group.pause!
    sign_in(@member)
    delete group_pause_path(@group.slug)
    assert_redirected_to group_path(@group.slug)
    assert @group.reload.paused?
  end
end
