require "test_helper"

class EventMailerTest < ActionMailer::TestCase
  test "notification sets to, subject, and body" do
    mail = EventMailer.notification(
      to: "test@example.com",
      subject: "You're invited",
      body: "Friday Hangout is happening today at 7:00 PM. See you there!"
    )

    assert_equal [ "test@example.com" ], mail.to
    assert_equal "You're invited", mail.subject
    assert_match "Friday Hangout", mail.body.encoded
  end
end
