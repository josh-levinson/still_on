class GenerateRecurringOccurrencesJob < ApplicationJob
  queue_as :default

  LOOKAHEAD_DAYS = 30

  def perform
    horizon = LOOKAHEAD_DAYS.days.from_now

    Event.active.recurring.find_each do |event|
      schedule = event.schedule
      next unless schedule

      generate_occurrences(event, schedule, horizon)
    end
  end

  private

  def generate_occurrences(event, schedule, horizon)
    upcoming = schedule.occurrences_between(Time.current, horizon)
    return if upcoming.empty?

    existing_times = event.event_occurrences
      .where(start_time: Time.current..horizon)
      .pluck(:start_time)
      .map { |t| t.to_i }
      .to_set

    duration = (event.default_duration_minutes || 120).minutes

    upcoming.each do |time|
      next if existing_times.include?(time.to_i)

      EventOccurrence.create!(
        event: event,
        start_time: time,
        end_time: time + duration,
        status: "scheduled"
      )
    end
  end
end
