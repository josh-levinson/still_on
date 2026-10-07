require "test_helper"

class AnalyticsReportTest < ActiveSupport::TestCase
  def visit(visitor)
    Ahoy::Visit.create!(visit_token: SecureRandom.uuid, visitor_token: visitor, started_at: Time.current)
  end

  def track(visit, name, time: Time.current, **properties)
    Ahoy::Event.create!(visit: visit, name: name, properties: properties, time: time)
  end

  test "onboarding_funnel counts unique visitors per step in wizard order" do
    a = visit("a")
    b = visit("b")
    track(a, "Onboarding step", step: "splash")
    track(a, "Onboarding step", step: "splash")
    track(a, "Onboarding step", step: "name")
    track(b, "Onboarding step", step: "splash")
    track(visit("a"), "Onboarding step", step: "invite")

    funnel = AnalyticsReport.new.onboarding_funnel
    assert_equal AnalyticsReport::ONBOARDING_STEPS, funnel.map(&:first)
    assert_equal({ "splash" => 2, "name" => 1, "date" => 0, "invite" => 1 }, funnel.to_h.slice("splash", "name", "date", "invite"))
  end

  test "rsvp_conversion counts first responses against page views" do
    a = visit("a")
    b = visit("b")
    track(a, "RSVP page viewed")
    track(b, "RSVP page viewed")
    track(a, "RSVP submitted", updated: false)
    track(b, "RSVP submitted", updated: true)

    assert_equal({ viewed: 2, submitted: 1, rate: 50.0 }, AnalyticsReport.new.rsvp_conversion)
  end

  test "ignores events before the window" do
    track(visit("a"), "RSVP page viewed", time: 40.days.ago)
    assert_equal({ viewed: 0, submitted: 0, rate: 0.0 }, AnalyticsReport.new.rsvp_conversion)
  end

  test "to_s prints both funnels with percentages" do
    a = visit("a")
    track(a, "Onboarding step", step: "splash")
    track(visit("b"), "Onboarding step", step: "splash")
    track(a, "Onboarding step", step: "invite")

    report = AnalyticsReport.new(since: 7.days.ago).to_s
    assert_match(/splash\s+2\s+100\.0%/, report)
    assert_match(/invite\s+1\s+50\.0%/, report)
    assert_match(/responded\s+0\s+0\.0%/, report)
  end
end
