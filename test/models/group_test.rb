require "test_helper"

class GroupTest < ActiveSupport::TestCase
  setup do
    @user = create_user
  end

  # --- validations ---

  test "is valid with name, created_by, and is_private" do
    group = create_group(@user, name: "Friday Crew")
    assert group.persisted?
  end

  test "is invalid without a name" do
    group = Group.new(created_by: @user, is_private: false)
    assert_not group.valid?
    assert_includes group.errors[:name], "can't be blank"
  end

  test "slug must be unique" do
    create_group(@user, name: "My Group")
    duplicate = Group.new(name: "My Group", created_by: @user, is_private: false)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "is_private must be true or false" do
    group = Group.new(name: "Private Check", created_by: @user, is_private: nil)
    assert_not group.valid?
    assert_includes group.errors[:is_private], "is not included in the list"
  end

  # --- slug generation ---

  test "generates slug from name on create" do
    group = create_group(@user, name: "Friday Night Crew")
    assert_equal "friday-night-crew", group.slug
  end

  test "does not overwrite an existing slug" do
    group = Group.create!(name: "Override Test", slug: "custom-slug", created_by: @user, is_private: false)
    assert_equal "custom-slug", group.slug
  end

  test "parameterizes slug (handles special chars and spaces)" do
    group = create_group(@user, name: "The A-Team & Friends!")
    assert_equal "the-a-team-friends", group.slug
  end

  # --- to_param ---

  test "to_param returns slug" do
    group = create_group(@user, name: "Slug Param Test")
    assert_equal "slug-param-test", group.to_param
  end

  # --- associations ---

  test "destroying group destroys its events" do
    group = create_group(@user)
    event = create_event(group, @user)
    assert_difference "Event.count", -1 do
      group.destroy
    end
  end

  test "has many members through group_memberships" do
    group = create_group(@user)
    member = create_user
    GroupMembership.create!(group: group, user: member)
    assert_includes group.members, member
  end
end
