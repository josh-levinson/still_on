require "test_helper"

class GroupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = create_user
    @other     = create_user
    @group     = create_group(@organizer)
  end

  # ---- GET /groups (index) ----

  test "index requires sign-in" do
    get groups_path
    assert_redirected_to onboarding_splash_path
  end

  test "index lists groups the signed-in user belongs to" do
    sign_in(@organizer)
    get groups_path
    assert_response :success
  end

  # ---- GET /groups/discover ----

  test "discover renders for guest" do
    get discover_groups_path
    assert_response :success
  end

  test "discover renders for signed-in user" do
    sign_in(@organizer)
    get discover_groups_path
    assert_response :success
  end

  test "discover filters by name when q param is present" do
    public_group = create_group(@organizer, name: "Unique Hangout Name")
    get discover_groups_path, params: { q: "Unique" }
    assert_response :success
    assert_match "Unique Hangout Name", response.body
  end

  test "discover excludes private groups" do
    private_group = create_group(@organizer, name: "Secret Group", is_private: true)
    get discover_groups_path
    assert_no_match "Secret Group", response.body
  end

  # ---- GET /groups/:slug (show) ----

  test "show renders a public group for guest" do
    get group_path(@group)
    assert_response :success
  end

  test "show renders a public group for signed-in non-member" do
    sign_in(@other)
    get group_path(@group)
    assert_response :success
  end

  test "show renders a private group for a member" do
    private_group = create_group(@organizer, is_private: true)
    GroupMembership.create!(group: private_group, user: @organizer)
    sign_in(@organizer)
    get group_path(private_group)
    assert_response :success
  end

  test "show redirects signed-in non-member away from private group" do
    private_group = create_group(@organizer, is_private: true)
    sign_in(@other)
    get group_path(private_group)
    assert_redirected_to groups_path
    assert_match /private/i, flash[:alert]
  end

  test "show redirects unauthenticated user away from private group" do
    private_group = create_group(@organizer, is_private: true)
    get group_path(private_group)
    assert_redirected_to sign_in_path
    assert_match /sign in/i, flash[:alert]
  end

  # ---- GET /groups/new ----

  test "new requires sign-in" do
    get new_group_path
    assert_redirected_to onboarding_splash_path
  end

  test "new renders form for signed-in user" do
    sign_in(@organizer)
    get new_group_path
    assert_response :success
  end

  # ---- POST /groups ----

  test "create requires sign-in" do
    post groups_path, params: { group: { name: "New Group" } }
    assert_redirected_to onboarding_splash_path
  end

  test "create saves group and redirects to show" do
    sign_in(@organizer)
    assert_difference "Group.count", 1 do
      post groups_path, params: { group: { name: "New Hangout", is_private: false } }
    end
    assert_redirected_to group_path(Group.order(:created_at).last)
    assert_match /successfully created/i, flash[:notice]
  end

  test "create auto-adds creator as member" do
    sign_in(@organizer)
    post groups_path, params: { group: { name: "New Hangout", is_private: false } }
    group = Group.order(:created_at).last
    assert group.member?(@organizer)
  end

  test "create re-renders new on invalid params" do
    sign_in(@organizer)
    assert_no_difference "Group.count" do
      post groups_path, params: { group: { name: "", is_private: false } }
    end
    assert_response :unprocessable_entity
  end

  # ---- GET /groups/:slug/edit ----

  test "edit requires sign-in" do
    get edit_group_path(@group)
    assert_redirected_to onboarding_splash_path
  end

  test "edit renders for organizer" do
    sign_in(@organizer)
    get edit_group_path(@group)
    assert_response :success
  end

  test "edit is forbidden for non-organizer" do
    sign_in(@other)
    get edit_group_path(@group)
    assert_redirected_to group_path(@group)
    assert_match /not authorized/i, flash[:alert]
  end

  # ---- PATCH /groups/:slug ----

  test "update requires sign-in" do
    patch group_path(@group), params: { group: { name: "Updated" } }
    assert_redirected_to onboarding_splash_path
  end

  test "update saves changes and redirects for organizer" do
    sign_in(@organizer)
    patch group_path(@group), params: { group: { name: "Renamed Group" } }
    assert_redirected_to group_path(@group)
    assert_match /successfully updated/i, flash[:notice]
    assert_equal "Renamed Group", @group.reload.name
  end

  test "update re-renders edit on invalid params" do
    sign_in(@organizer)
    patch group_path(@group), params: { group: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "update is forbidden for non-organizer" do
    sign_in(@other)
    patch group_path(@group), params: { group: { name: "Hacked" } }
    assert_redirected_to group_path(@group)
    assert_match /not authorized/i, flash[:alert]
  end

  # ---- DELETE /groups/:slug ----

  test "destroy requires sign-in" do
    delete group_path(@group)
    assert_redirected_to onboarding_splash_path
  end

  test "destroy deletes group and redirects to index for organizer" do
    sign_in(@organizer)
    assert_difference "Group.count", -1 do
      delete group_path(@group)
    end
    assert_redirected_to groups_url
    assert_match /successfully deleted/i, flash[:notice]
  end

  test "destroy is forbidden for non-organizer" do
    sign_in(@other)
    assert_no_difference "Group.count" do
      delete group_path(@group)
    end
    assert_redirected_to group_path(@group)
    assert_match /not authorized/i, flash[:alert]
  end
end
