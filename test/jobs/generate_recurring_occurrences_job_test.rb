require "test_helper"

class GenerateRecurringOccurrencesJobTest < ActiveSupport::TestCase
  setup do
    @user  = create_user
    @group = create_group(@user)
  end

  test "creates occurrences for active recurring events within lookahead window" do
    event = create_event(@group, @user, recurrence_type: "weekly")
    start_time = 3.days.from_now.change(hour: 19, min: 0, sec: 0)
    event.build_schedule(start_time)
    event.save!

    expected_count = event.next_occurrences(10).count { |t| t <= 30.days.from_now }
    assert_difference "EventOccurrence.count", expected_count do
      GenerateRecurringOccurrencesJob.perform_now
    end
  end

  test "does not create duplicate occurrences on re-run" do
    event = create_event(@group, @user, recurrence_type: "weekly")
    start_time = 3.days.from_now.change(hour: 19, min: 0, sec: 0)
    event.build_schedule(start_time)
    event.save!

    GenerateRecurringOccurrencesJob.perform_now
    count_after_first = EventOccurrence.count

    GenerateRecurringOccurrencesJob.perform_now
    assert_equal count_after_first, EventOccurrence.count
  end

  test "skips inactive events" do
    event = create_event(@group, @user, recurrence_type: "weekly", is_active: false)
    start_time = 3.days.from_now.change(hour: 19, min: 0, sec: 0)
    event.build_schedule(start_time)
    event.save!

    assert_no_difference "EventOccurrence.count" do
      GenerateRecurringOccurrencesJob.perform_now
    end
  end

  test "skips non-recurring events" do
    create_event(@group, @user, recurrence_type: "none")

    assert_no_difference "EventOccurrence.count" do
      GenerateRecurringOccurrencesJob.perform_now
    end
  end

  test "skips events with no occurrences in the lookahead window" do
    # Schedule starts 60 days out — beyond the 30-day lookahead
    event = create_event(@group, @user, recurrence_type: "weekly")
    start_time = 60.days.from_now.change(hour: 19, min: 0, sec: 0)
    event.build_schedule(start_time)
    event.save!

    assert_no_difference "EventOccurrence.count" do
      GenerateRecurringOccurrencesJob.perform_now
    end
  end

  test "skips events without a recurrence_rule" do
    event = create_event(@group, @user, recurrence_type: "weekly")
    # no build_schedule call — recurrence_rule is blank

    assert_no_difference "EventOccurrence.count" do
      GenerateRecurringOccurrencesJob.perform_now
    end
  end

  test "uses default_duration_minutes when set" do
    event = create_event(@group, @user, recurrence_type: "weekly", default_duration_minutes: 90)
    start_time = 3.days.from_now.change(hour: 19, min: 0, sec: 0)
    event.build_schedule(start_time)
    event.save!

    GenerateRecurringOccurrencesJob.perform_now

    occurrence = EventOccurrence.where(event: event).first
    assert_not_nil occurrence
    assert_equal 90.minutes, occurrence.end_time - occurrence.start_time
  end

  test "falls back to 120 minute duration when default_duration_minutes is nil" do
    event = create_event(@group, @user, recurrence_type: "weekly", default_duration_minutes: nil)
    start_time = 3.days.from_now.change(hour: 19, min: 0, sec: 0)
    event.build_schedule(start_time)
    event.save!

    GenerateRecurringOccurrencesJob.perform_now

    occurrence = EventOccurrence.where(event: event).first
    assert_not_nil occurrence
    assert_equal 120.minutes, occurrence.end_time - occurrence.start_time
  end

  test "skips occurrences for an indefinitely paused group" do
    event = create_event(@group, @user, recurrence_type: "weekly")
    event.build_schedule(3.days.from_now.change(hour: 19, min: 0, sec: 0))
    event.save!
    @group.pause!

    assert_no_difference "EventOccurrence.count" do
      GenerateRecurringOccurrencesJob.perform_now
    end
  end

  test "only creates occurrences after a paused group's resume date" do
    event = create_event(@group, @user, recurrence_type: "weekly")
    event.build_schedule(3.days.from_now.change(hour: 19, min: 0, sec: 0))
    event.save!
    @group.pause!(until_date: 15.days.from_now.to_date)

    GenerateRecurringOccurrencesJob.perform_now

    times = event.event_occurrences.pluck(:start_time)
    assert times.any?
    assert times.all? { |t| t >= @group.resumes_at }
  end

  test "pings its Honeybadger check-in after running" do
    pinged = []
    ENV["HONEYBADGER_CHECKIN_GENERATE_RECURRING_OCCURRENCES"] = "hb-check-in"
    Honeybadger.stub(:check_in, ->(id) { pinged << id }) do
      GenerateRecurringOccurrencesJob.perform_now
    end

    assert_equal [ "hb-check-in" ], pinged
  ensure
    ENV.delete("HONEYBADGER_CHECKIN_GENERATE_RECURRING_OCCURRENCES")
  end
end
