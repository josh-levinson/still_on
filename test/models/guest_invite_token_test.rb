require "test_helper"

class GuestInviteTokenTest < ActiveSupport::TestCase
  setup do
    @user = create_user
    @group = create_group(@user)
    @event = create_event(@group, @user)
    @occurrence = create_occurrence(@event)
    @phone = "+15550001234"
  end

  test "for generates a short, URL-safe token" do
    invite = GuestInviteToken.for(@occurrence, @phone)
    assert_match(/\A[A-Za-z0-9_-]+\z/, invite.token)
    assert invite.token.length <= 16
    assert_equal @phone, invite.phone
    assert_equal @occurrence, invite.event_occurrence
  end

  test "for reuses the same token for the same occurrence and phone" do
    first = GuestInviteToken.for(@occurrence, @phone)
    second = GuestInviteToken.for(@occurrence, @phone)
    assert_equal first.id, second.id
    assert_equal first.token, second.token
  end

  test "for mints distinct tokens for different phones" do
    a = GuestInviteToken.for(@occurrence, @phone)
    b = GuestInviteToken.for(@occurrence, "+15550009999")
    assert_not_equal a.token, b.token
  end

  test "an explicitly provided token is preserved" do
    invite = GuestInviteToken.create!(event_occurrence: @occurrence, phone: @phone, token: "preset-token")
    assert_equal "preset-token", invite.token
  end

  test "token generation retries on collision" do
    taken = GuestInviteToken.for(@occurrence, @phone).token
    candidates = [ taken, "fresh-guest-token" ]
    SecureRandom.stub(:urlsafe_base64, ->(*) { candidates.shift }) do
      invite = GuestInviteToken.for(@occurrence, "+15550007777")
      assert_equal "fresh-guest-token", invite.token
    end
  end

  test "requires a phone" do
    invite = GuestInviteToken.new(event_occurrence: @occurrence)
    assert_not invite.valid?
    assert_includes invite.errors[:phone], "can't be blank"
  end
end
