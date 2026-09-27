require "test_helper"

class GuestGroupSubscriptionTest < ActiveSupport::TestCase
  setup do
    @user  = create_user
    @group = create_group(@user)
    @phone = "+15550002001"
  end

  test "subscribed? reflects whether the phone is subscribed to the group" do
    assert_not GuestGroupSubscription.subscribed?(group: @group, phone_number: @phone)
    GuestGroupSubscription.subscribe(group: @group, phone_number: @phone)
    assert GuestGroupSubscription.subscribed?(group: @group, phone_number: @phone)
  end

  test "subscribed? is false for a blank phone" do
    assert_not GuestGroupSubscription.subscribed?(group: @group, phone_number: nil)
  end

  test "subscribe creates a new subscription" do
    assert_difference "GuestGroupSubscription.count", 1 do
      GuestGroupSubscription.subscribe(group: @group, phone_number: @phone)
    end
  end

  test "subscribe is idempotent" do
    GuestGroupSubscription.subscribe(group: @group, phone_number: @phone)
    assert_no_difference "GuestGroupSubscription.count" do
      GuestGroupSubscription.subscribe(group: @group, phone_number: @phone)
    end
  end

  test "unsubscribe destroys an existing subscription" do
    GuestGroupSubscription.create!(group: @group, phone_number: @phone)
    assert_difference "GuestGroupSubscription.count", -1 do
      GuestGroupSubscription.unsubscribe(group: @group, phone_number: @phone)
    end
  end

  test "unsubscribe returns nil when no subscription exists" do
    result = GuestGroupSubscription.unsubscribe(group: @group, phone_number: @phone)
    assert_nil result
  end
end
