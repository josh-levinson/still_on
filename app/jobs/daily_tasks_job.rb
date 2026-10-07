# Runs the daily scheduled work in order and pings one Honeybadger check-in
# once all of it has succeeded. If any step raises, the check-in is skipped
# and Honeybadger alerts when it goes missing.
class DailyTasksJob < ApplicationJob
  queue_as :default

  def perform
    GenerateRecurringOccurrencesJob.perform_now
    ScheduleNotificationsJob.perform_now

    check_in(:daily_tasks)
  end
end
