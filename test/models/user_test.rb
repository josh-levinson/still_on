require "test_helper"

class UserTest < ActiveSupport::TestCase
  # --- full_name ---

  test "full_name returns first and last name when both present" do
    user = build_user(first_name: "Alice", last_name: "Smith")
    assert_equal "Alice Smith", user.full_name
  end

  test "full_name returns first name only when last name is absent" do
    user = build_user(first_name: "Alice", last_name: nil)
    assert_equal "Alice", user.full_name
  end

  test "full_name falls back to username when no name present" do
    user = build_user(first_name: nil, last_name: nil, username: "cooluser")
    assert_equal "cooluser", user.full_name
  end

  test "full_name falls back to phone_number when no name or username" do
    user = build_user(first_name: nil, last_name: nil, username: nil, phone_number: "+15551234567")
    assert_equal "+15551234567", user.full_name
  end

  # --- validations ---

  test "phone_number must be unique" do
    create_user(phone_number: "+15550000001", username: "user_a")
    duplicate = build_user(phone_number: "+15550000001", username: "user_b")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:phone_number], "has already been taken"
  end

  test "phone_number allows blank (multiple users without phone)" do
    u1 = create_user(phone_number: nil, username: "no_phone_1")
    u2 = build_user(phone_number: nil, username: "no_phone_2")
    assert u2.valid?
  end

  test "username must be unique" do
    create_user(username: "shared_name")
    duplicate = build_user(username: "shared_name")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:username], "has already been taken"
  end

  test "username allows nil (multiple users without username)" do
    create_user(username: nil)
    second = build_user(username: nil)
    assert second.valid?
  end

  # --- claim_guest_rsvps ---

  test "claim_guest_rsvps adopts matching guest RSVPs when phone is set" do
    user = create_user(phone_number: nil, username: "claimer")
    group = create_group(user)
    event = create_event(group, user)
    occurrence = create_occurrence(event)

    guest_rsvp = create_rsvp(occurrence, guest_name: "Claimer", guest_phone: "+15550009999", user: nil)

    user.update!(phone_number: "+15550009999")

    guest_rsvp.reload
    assert_equal user.id, guest_rsvp.user_id
    assert_nil guest_rsvp.guest_name
    assert_nil guest_rsvp.guest_phone
  end

  test "claim_guest_rsvps skips occurrence if user already has an RSVP for it" do
    user = create_user(phone_number: nil, username: "existing_rsvper")
    group = create_group(user)
    event = create_event(group, user)
    occurrence = create_occurrence(event)

    # User already has an RSVP for this occurrence
    existing_rsvp = create_rsvp(occurrence, user: user, guest_name: nil, guest_phone: nil)

    # Guest RSVP with same phone
    guest_rsvp = create_rsvp(occurrence, guest_name: "Someone", guest_phone: "+15550008888", user: nil)

    user.update!(phone_number: "+15550008888")

    guest_rsvp.reload
    # Should NOT be claimed because user already has an RSVP for this occurrence
    assert_nil guest_rsvp.user_id
    assert_equal "Someone", guest_rsvp.guest_name
  end

  test "claim_guest_rsvps does not run when phone_number is not changed" do
    user = create_user(phone_number: "+15550007777", username: "no_claim")
    group = create_group(user)
    event = create_event(group, user)
    occurrence = create_occurrence(event)

    guest_rsvp = create_rsvp(occurrence, guest_name: "Someone Else", guest_phone: "+15550007777", user: nil)

    # Update a non-phone attribute
    user.update!(first_name: "Updated")

    guest_rsvp.reload
    assert_nil guest_rsvp.user_id
  end
end
