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

    assert_difference "EventOccurrence.count", -> { event.next_occurrences(10).count { |t| t <= 30.days.from_now } } do
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
end
