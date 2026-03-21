require "test_helper"

class ScheduleNotificationsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user  = create_user
    @group = create_group(@user)
    @event = create_event(@group, @user)
  end

  test "enqueues RSVP reminders for occurrences 2 days out" do
    occurrence = create_occurrence(@event, start_time: 2.days.from_now.change(hour: 19), end_time: 2.days.from_now.change(hour: 21))

    assert_enqueued_with(job: SendRsvpReminderJob, args: [ occurrence.id ]) do
      ScheduleNotificationsJob.perform_now
    end
  end

  test "enqueues event reminders for occurrences happening today after the min hours threshold" do
    travel_to Time.current.noon do
      occurrence = create_occurrence(@event, start_time: 4.hours.from_now, end_time: 6.hours.from_now)

      assert_enqueued_with(job: SendEventReminderJob, args: [ occurrence.id ]) do
        ScheduleNotificationsJob.perform_now
      end
    end
  end

  test "does not enqueue RSVP reminder for occurrences too far out" do
    create_occurrence(@event, start_time: 5.days.from_now, end_time: 5.days.from_now + 2.hours)

    assert_no_enqueued_jobs only: SendRsvpReminderJob do
      ScheduleNotificationsJob.perform_now
    end
  end

  test "does not enqueue event reminder for occurrences starting within the min hours threshold" do
    create_occurrence(@event, start_time: 1.hour.from_now, end_time: 3.hours.from_now)

    assert_no_enqueued_jobs only: SendEventReminderJob do
      ScheduleNotificationsJob.perform_now
    end
  end

  test "enqueues quorum alert for occurrence in the 24h window with quorum set" do
    travel_to Time.current.noon do
      event = create_event(@group, @user, quorum: 3)
      occurrence = create_occurrence(event, start_time: 25.hours.from_now, end_time: 27.hours.from_now)

      assert_enqueued_with(job: SendQuorumAlertJob, args: [ occurrence.id ]) do
        ScheduleNotificationsJob.perform_now
      end
    end
  end

  test "does not enqueue quorum alert when event has no quorum" do
    travel_to Time.current.noon do
      event = create_event(@group, @user)  # quorum defaults to nil
      create_occurrence(event, start_time: 25.hours.from_now, end_time: 27.hours.from_now)

      assert_no_enqueued_jobs only: SendQuorumAlertJob do
        ScheduleNotificationsJob.perform_now
      end
    end
  end

  test "does not enqueue reminders for cancelled occurrences" do
    create_occurrence(@event, start_time: 2.days.from_now.change(hour: 19), end_time: 2.days.from_now.change(hour: 21), status: "cancelled")

    assert_no_enqueued_jobs only: SendRsvpReminderJob do
      ScheduleNotificationsJob.perform_now
    end
  end
end
