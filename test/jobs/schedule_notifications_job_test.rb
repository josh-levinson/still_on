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

  test "enqueues RSVP reminders using group's custom reminder_days_before" do
    @group.update!(reminder_days_before: 5)
    occurrence = create_occurrence(@event, start_time: 5.days.from_now.change(hour: 19), end_time: 5.days.from_now.change(hour: 21))

    assert_enqueued_with(job: SendRsvpReminderJob, args: [ occurrence.id ]) do
      ScheduleNotificationsJob.perform_now
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

  test "uses group time zone to bound the same-day event reminder window" do
    # Cron fires at 8am UTC = 4am EDT. Group in EDT has an event at 10pm EDT today
    # (= 2am UTC tomorrow). Without tz-aware bounds the event would fall outside
    # Time.current.end_of_day (23:59 UTC today) and be missed.
    edt = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    edt_group = create_group(@user, time_zone: edt.name)
    edt_event = create_event(edt_group, @user)

    travel_to Time.utc(2026, 5, 1, 8, 0) do
      occurrence = create_occurrence(edt_event,
        start_time: edt.local(2026, 5, 1, 22),
        end_time:   edt.local(2026, 5, 1, 23))

      assert_enqueued_with(job: SendEventReminderJob, args: [ occurrence.id ]) do
        ScheduleNotificationsJob.perform_now
      end
    end
  end

  test "defers same-day event reminders to 9am local instead of firing immediately" do
    edt = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    edt_group = create_group(@user, time_zone: edt.name)
    edt_event = create_event(edt_group, @user)

    travel_to Time.utc(2026, 5, 1, 8, 0) do # 4am EDT
      occurrence = create_occurrence(edt_event,
        start_time: edt.local(2026, 5, 1, 19),
        end_time:   edt.local(2026, 5, 1, 21))

      ScheduleNotificationsJob.perform_now

      job = enqueued_jobs.find { |j| j["job_class"] == "SendEventReminderJob" && j["arguments"] == [ occurrence.id ] }
      assert job, "expected SendEventReminderJob to be enqueued"

      expected = edt.local(2026, 5, 1, 9)
      assert_in_delta expected.to_f, Time.parse(job["scheduled_at"]).to_f, 1
    end
  end

  test "uses group time zone to bound the RSVP reminder window" do
    # 2 days from now at 11pm EDT = 3am UTC three days from now — outside the
    # UTC-based 2-days-out window but inside the EDT-local one.
    edt = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    edt_group = create_group(@user, time_zone: edt.name)
    edt_event = create_event(edt_group, @user)

    travel_to Time.utc(2026, 5, 1, 8, 0) do
      occurrence = create_occurrence(edt_event,
        start_time: edt.local(2026, 5, 3, 23),
        end_time:   edt.local(2026, 5, 3, 23, 30))

      assert_enqueued_with(job: SendRsvpReminderJob, args: [ occurrence.id ]) do
        ScheduleNotificationsJob.perform_now
      end
    end
  end

  test "delivers immediately when local time is already past the morning threshold" do
    # Group in UTC, cron fires at noon UTC — past the 9am local threshold,
    # so wait_until should fall back to current time rather than tomorrow 9am.
    travel_to Time.utc(2026, 5, 1, 12, 0) do
      occurrence = create_occurrence(@event, start_time: 4.hours.from_now, end_time: 6.hours.from_now)

      ScheduleNotificationsJob.perform_now

      job = enqueued_jobs.find { |j| j["job_class"] == "SendEventReminderJob" && j["arguments"] == [ occurrence.id ] }
      assert job
      assert_in_delta Time.current.to_f, Time.parse(job["scheduled_at"]).to_f, 1
    end
  end
end
