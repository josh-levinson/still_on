# Funnel numbers from Ahoy events, counted in unique visitors (browsers).
# Print it with `bin/rails "analytics:report[30]"` (the argument is days back).
class AnalyticsReport
  ONBOARDING_STEPS = %w[splash name date cadence phone verify invite].freeze

  def initialize(since: 30.days.ago)
    @since = since
  end

  # [[step, visitors], ...] in wizard order. "invite" means signup finished.
  def onboarding_funnel
    counts = events("Onboarding step").group("ahoy_events.properties ->> 'step'").count("DISTINCT ahoy_visits.visitor_token")
    ONBOARDING_STEPS.map { |step| [ step, counts.fetch(step, 0) ] }
  end

  # Visitors who opened an RSVP link vs. those who then sent a first response.
  def rsvp_conversion
    viewed    = unique_visitors(events("RSVP page viewed"))
    submitted = unique_visitors(events("RSVP submitted").where_props(updated: false))
    { viewed: viewed, submitted: submitted, rate: percent(submitted, viewed) }
  end

  def to_s
    lines = [ "Since #{@since.to_date}", "", "Onboarding (unique visitors)" ]
    start = onboarding_funnel.first.last
    onboarding_funnel.each do |step, count|
      lines << format("  %-8s %5d  %5.1f%%", step, count, percent(count, start))
    end
    rsvp = rsvp_conversion
    lines << "" << "Guest RSVP"
    lines << format("  viewed    %5d", rsvp[:viewed])
    lines << format("  responded %5d  %5.1f%%", rsvp[:submitted], rsvp[:rate])
    lines.join("\n")
  end

  private

  def events(name)
    Ahoy::Event.joins(:visit).where(name: name, time: @since..)
  end

  def unique_visitors(scope)
    scope.distinct.count("ahoy_visits.visitor_token")
  end

  def percent(part, whole)
    whole.zero? ? 0.0 : (part * 100.0 / whole).round(1)
  end
end
