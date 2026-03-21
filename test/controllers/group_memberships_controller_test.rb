require "test_helper"

class GroupMembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = create_user
    @member    = create_user
    @other     = create_user
    @group     = create_group(@organizer)
    GroupMembership.create!(group: @group, user: @organizer, role: :organizer)
    GroupMembership.create!(group: @group, user: @member)
  end

  # ---- POST /groups/:group_slug/membership (join) ----

  test "create requires sign-in" do
    post group_membership_path(@group.slug)
    assert_redirected_to onboarding_splash_path
  end

  test "create joins a public group as a new member" do
    sign_in(@other)
    assert_difference "GroupMembership.count", 1 do
      post group_membership_path(@group.slug)
    end
    assert_redirected_to group_path(@group.slug)
    assert_match /joined/i, flash[:notice]
  end

  test "create redirects with alert if already a member" do
    sign_in(@member)
    assert_no_difference "GroupMembership.count" do
      post group_membership_path(@group.slug)
    end
    assert_redirected_to group_path(@group.slug)
    assert_match /already a member/i, flash[:alert]
  end

  test "create redirects with alert for private group" do
    private_group = create_group(@organizer, is_private: true)
    sign_in(@other)
    assert_no_difference "GroupMembership.count" do
      post group_membership_path(private_group.slug)
    end
    assert_redirected_to group_path(private_group.slug)
    assert_match /private/i, flash[:alert]
  end

  # ---- DELETE /groups/:group_slug/membership (leave) ----

  test "destroy requires sign-in" do
    delete group_membership_path(@group.slug)
    assert_redirected_to onboarding_splash_path
  end

  test "destroy leaves the group as a non-creator member" do
    sign_in(@member)
    assert_difference "GroupMembership.count", -1 do
      delete group_membership_path(@group.slug)
    end
    assert_redirected_to groups_path
    assert_match /left/i, flash[:notice]
  end

  test "destroy redirects with alert if group creator tries to leave" do
    sign_in(@organizer)
    assert_no_difference "GroupMembership.count" do
      delete group_membership_path(@group.slug)
    end
    assert_redirected_to group_path(@group.slug)
    assert_match /creator cannot leave/i, flash[:alert]
  end

  test "destroy redirects with alert if user is not a member" do
    sign_in(@other)
    assert_no_difference "GroupMembership.count" do
      delete group_membership_path(@group.slug)
    end
    assert_redirected_to group_path(@group.slug)
    assert_match /not a member/i, flash[:alert]
  end

  # ---- POST /groups/:group_slug/group_memberships/:user_id/promote ----

  test "promote requires sign-in" do
    post promote_group_group_membership_path(@group.slug, @member.id)
    assert_redirected_to onboarding_splash_path
  end

  test "promote is forbidden for a non-organizer" do
    sign_in(@member)
    post promote_group_group_membership_path(@group.slug, @other.id)
    assert_redirected_to group_path(@group)
    assert_match /not authorized/i, flash[:alert]
  end

  test "promote elevates a member to organizer" do
    sign_in(@organizer)
    post promote_group_group_membership_path(@group.slug, @member.id)
    assert_redirected_to group_path(@group)
    assert_match /co-organizer/i, flash[:notice]
    assert_equal "organizer", GroupMembership.find_by(group: @group, user: @member).role
  end

  # ---- POST /groups/:group_slug/group_memberships/:user_id/demote ----

  test "demote requires sign-in" do
    post demote_group_group_membership_path(@group.slug, @member.id)
    assert_redirected_to onboarding_splash_path
  end

  test "demote is forbidden for a non-organizer" do
    sign_in(@member)
    post demote_group_group_membership_path(@group.slug, @other.id)
    assert_redirected_to group_path(@group)
    assert_match /not authorized/i, flash[:alert]
  end

  test "demote reduces a co-organizer to member" do
    GroupMembership.find_by(group: @group, user: @member).update!(role: :organizer)
    sign_in(@organizer)
    post demote_group_group_membership_path(@group.slug, @member.id)
    assert_redirected_to group_path(@group)
    assert_match /member/i, flash[:notice]
    assert_equal "member", GroupMembership.find_by(group: @group, user: @member).role
  end

  test "demote redirects with alert when trying to demote the group creator" do
    sign_in(@organizer)
    post demote_group_group_membership_path(@group.slug, @organizer.id)
    assert_redirected_to group_path(@group)
    assert_match /creator cannot be demoted/i, flash[:alert]
  end
end
