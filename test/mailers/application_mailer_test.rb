require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  test "has correct default from address" do
    assert_equal "from@example.com", ApplicationMailer.default[:from]
  end

  test "uses mailer layout" do
    assert_equal "mailer", ApplicationMailer._layout
  end
end
