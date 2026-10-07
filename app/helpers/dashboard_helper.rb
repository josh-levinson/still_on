module DashboardHelper
  CADENCE_LABELS = {
    "daily" => "Daily",
    "weekly" => "Weekly",
    "biweekly" => "Every other week",
    "monthly" => "Monthly"
  }.freeze

  def cadence_label(event)
    CADENCE_LABELS.fetch(event.recurrence_type, "One-time")
  end

  # "Fri Oct 3 · 7:00 PM" in the group's time zone.
  def hangout_time(occurrence, group)
    local = occurrence.start_time.in_time_zone(group.time_zone)
    "#{local.strftime("%a %b %-d")} · #{local.strftime("%-l:%M %p")}"
  end
end
