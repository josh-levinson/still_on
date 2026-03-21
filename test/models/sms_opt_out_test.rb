require "test_helper"

class SmsOptOutTest < ActiveSupport::TestCase
  test "opted_out? returns false when phone has not opted out" do
    assert_not SmsOptOut.opted_out?("+15550001001")
  end

  test "opted_out? returns true when phone has opted out" do
    SmsOptOut.create!(phone_number: "+15550001002")
    assert SmsOptOut.opted_out?("+15550001002")
  end

  test "opt_out! creates a record" do
    assert_difference "SmsOptOut.count", 1 do
      SmsOptOut.opt_out!("+15550001003")
    end
  end

  test "opt_out! is idempotent" do
    SmsOptOut.opt_out!("+15550001004")
    assert_no_difference "SmsOptOut.count" do
      SmsOptOut.opt_out!("+15550001004")
    end
  end
end
