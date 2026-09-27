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

  # --- pausing ---

  test "a new group is not paused" do
    group = create_group(@user)
    assert_not group.paused?
    assert_nil group.resumes_at
  end

  test "pause! without a date pauses indefinitely" do
    group = create_group(@user)
    group.pause!
    assert group.paused?
    assert group.paused_during?(1.year.from_now)
    assert_nil group.resumes_at
  end

  test "pause! with a date pauses until the start of that day in the group time zone" do
    group = create_group(@user, time_zone: "Pacific Time (US & Canada)")
    resume_date = 10.days.from_now.in_time_zone(group.time_zone).to_date
    group.pause!(until_date: resume_date)

    resumes_at = resume_date.in_time_zone("Pacific Time (US & Canada)")
    assert_equal resumes_at, group.resumes_at
    assert group.paused?
    assert group.paused_during?(resumes_at - 1.minute)
    assert_not group.paused_during?(resumes_at)
  end

  test "pause lifts automatically once the resume date arrives" do
    group = create_group(@user)
    group.pause!(until_date: 3.days.from_now.to_date)
    travel 4.days do
      assert_not group.paused?
    end
  end

  test "resume! clears the pause" do
    group = create_group(@user)
    group.pause!(until_date: 3.days.from_now.to_date)
    group.resume!
    assert_not group.paused?
    assert_nil group.paused_at
    assert_nil group.paused_until
  end

  test "paused_until must be in the future" do
    group = create_group(@user)
    today = Time.current.in_time_zone(group.time_zone).to_date
    assert_raises(ActiveRecord::RecordInvalid) { group.pause!(until_date: today) }
    assert_includes group.errors[:paused_until], "must be in the future"
  end

  test "an elapsed paused_until does not block unrelated updates" do
    group = create_group(@user)
    group.pause!(until_date: 2.days.from_now.to_date)
    travel 5.days do
      assert group.update(name: "Renamed")
    end
  end

  # --- next_occurrence ---

  test "next_occurrence returns the soonest scheduled upcoming occurrence across events" do
    group = create_group(@user)
    weekly = create_event(group, @user)
    one_off = create_event(group, @user, recurrence_type: "none")
    create_occurrence(weekly, start_time: 1.day.ago, end_time: 1.day.ago + 1.hour)
    create_occurrence(weekly, start_time: 2.days.from_now, end_time: 2.days.from_now + 1.hour, status: "cancelled")
    later = create_occurrence(weekly, start_time: 5.days.from_now, end_time: 5.days.from_now + 1.hour)
    sooner = create_occurrence(one_off, start_time: 3.days.from_now, end_time: 3.days.from_now + 1.hour)

    assert_equal sooner, group.next_occurrence
    sooner.update!(status: "cancelled")
    assert_equal later, group.next_occurrence
  end

  test "next_occurrence is nil when nothing is scheduled" do
    assert_nil create_group(@user).next_occurrence
  end
end
