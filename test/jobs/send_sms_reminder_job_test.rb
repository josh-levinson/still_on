require "test_helper"

class SendSmsReminderJobTest < ActiveSupport::TestCase
  test "is an alias for SendRsvpReminderJob" do
    assert_equal SendRsvpReminderJob, SendSmsReminderJob
  end
end
