require "test_helper"
require "fugit"

class RecurringScheduleTest < ActiveSupport::TestCase
  # Production servers run in UTC, so a schedule without a zone fires hours
  # early and misses the Honeybadger check-in window.
  test "the daily job is pinned to a time zone" do
    config = YAML.load_file(Rails.root.join("config/recurring.yml"))["production"]

    task = config.fetch("daily_tasks")
    cron = Fugit.parse(task["schedule"])

    assert_equal "DailyTasksJob", task["class"]
    assert_kind_of Fugit::Cron, cron
    assert_equal "America/New_York", cron.timezone&.name
  end
end
