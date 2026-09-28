require "test_helper"

class DailyTasksJobTest < ActiveJob::TestCase
  setup { ENV["HONEYBADGER_CHECKIN_DAILY_TASKS"] = "hb-check-in" }
  teardown { ENV.delete("HONEYBADGER_CHECKIN_DAILY_TASKS") }

  test "runs occurrence generation before notifications, then pings the check-in" do
    calls = []
    GenerateRecurringOccurrencesJob.stub(:perform_now, -> { calls << :generate }) do
      ScheduleNotificationsJob.stub(:perform_now, -> { calls << :notify }) do
        Honeybadger.stub(:check_in, ->(id) { calls << id }) do
          DailyTasksJob.perform_now
        end
      end
    end

    assert_equal [ :generate, :notify, "hb-check-in" ], calls
  end

  test "skips the check-in when a step fails" do
    pinged = []
    GenerateRecurringOccurrencesJob.stub(:perform_now, -> { raise "boom" }) do
      Honeybadger.stub(:check_in, ->(id) { pinged << id }) do
        assert_raises(RuntimeError) { DailyTasksJob.perform_now }
      end
    end

    assert_empty pinged
  end
end
