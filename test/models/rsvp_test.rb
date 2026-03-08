require "test_helper"

class RsvpTest < ActiveSupport::TestCase
  setup do
    @user = create_user
    @group = create_group(@user)
    @event = create_event(@group, @user)
    @occurrence = create_occurrence(@event)
  end

  # --- validations ---

  test "is valid as a guest RSVP with guest_name" do
    rsvp = create_rsvp(@occurrence, guest_name: "Alex", user: nil)
    assert rsvp.persisted?
  end

  test "is valid as an authenticated RSVP with a user" do
    rsvp = Rsvp.create!(event_occurrence: @occurrence, user: @user, status: "attending", guest_count: 0)
    assert rsvp.persisted?
  end

  test "is invalid without either user or guest_name" do
    rsvp = Rsvp.new(event_occurrence: @occurrence, status: "attending", guest_count: 0)
    assert_not rsvp.valid?
    assert_includes rsvp.errors[:base], "Must have either a user or a guest name"
  end

  test "status must be present" do
    rsvp = Rsvp.new(event_occurrence: @occurrence, guest_name: "No Status", guest_count: 0)
    assert_not rsvp.valid?
    assert_includes rsvp.errors[:status], "can't be blank"
  end

  test "status must be attending, declined, or maybe" do
    rsvp = Rsvp.new(event_occurrence: @occurrence, guest_name: "Bad Status", status: "unknown", guest_count: 0)
    assert_not rsvp.valid?
    assert_includes rsvp.errors[:status], "is not included in the list"
  end

  test "accepts all valid statuses" do
    %w[attending declined maybe].each do |s|
      rsvp = Rsvp.new(event_occurrence: @occurrence, guest_name: "Status Test", status: s, guest_count: 0)
      assert rsvp.valid?, "Expected #{s} to be valid, got: #{rsvp.errors.full_messages}"
    end
  end

  test "guest_count must be >= 0" do
    rsvp = Rsvp.new(event_occurrence: @occurrence, guest_name: "Negative Guest", status: "attending", guest_count: -1)
    assert_not rsvp.valid?
    assert_includes rsvp.errors[:guest_count], "must be greater than or equal to 0"
  end

  test "a user cannot have two RSVPs for the same occurrence" do
    Rsvp.create!(event_occurrence: @occurrence, user: @user, status: "attending", guest_count: 0)
    duplicate = Rsvp.new(event_occurrence: @occurrence, user: @user, status: "maybe", guest_count: 0)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "different users can RSVP to the same occurrence" do
    second_user = create_user
    Rsvp.create!(event_occurrence: @occurrence, user: @user, status: "attending", guest_count: 0)
    second_rsvp = Rsvp.new(event_occurrence: @occurrence, user: second_user, status: "attending", guest_count: 0)
    assert second_rsvp.valid?
  end

  test "guest_name uniqueness is not enforced (multiple guests with same name allowed)" do
    create_rsvp(@occurrence, guest_name: "Common Name", guest_phone: nil)
    second_occurrence = create_occurrence(@event)
    # Same guest name on different occurrence is fine
    rsvp2 = Rsvp.new(event_occurrence: second_occurrence, guest_name: "Common Name", status: "attending", guest_count: 0)
    assert rsvp2.valid?
  end

  # --- guest_rsvp? ---

  test "guest_rsvp? returns true when no user_id" do
    rsvp = create_rsvp(@occurrence, user: nil)
    assert rsvp.guest_rsvp?
  end

  test "guest_rsvp? returns false when user is set" do
    rsvp = Rsvp.create!(event_occurrence: @occurrence, user: @user, status: "attending", guest_count: 0)
    assert_not rsvp.guest_rsvp?
  end

  # --- display_name ---

  test "display_name returns user's full_name for authenticated RSVPs" do
    member = create_user(first_name: "Jordan", last_name: "Lee")
    rsvp = Rsvp.create!(event_occurrence: @occurrence, user: member, status: "attending", guest_count: 0)
    assert_equal "Jordan Lee", rsvp.display_name
  end

  test "display_name returns guest_name for guest RSVPs" do
    rsvp = create_rsvp(@occurrence, guest_name: "Sam Guestperson", user: nil)
    assert_equal "Sam Guestperson", rsvp.display_name
  end

  test "display_name returns Guest when no user and no guest_name" do
    # Build directly to bypass validation for this edge case test
    rsvp = Rsvp.new(event_occurrence: @occurrence, user: nil, guest_name: nil, status: "attending", guest_count: 0)
    assert_equal "Guest", rsvp.display_name
  end
end
