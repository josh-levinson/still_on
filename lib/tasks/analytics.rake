namespace :analytics do
  desc "Print onboarding and guest RSVP funnels (optional: days back, default 30)"
  task :report, [ :days ] => :environment do |_t, args|
    days = (args[:days] || 30).to_i
    puts AnalyticsReport.new(since: days.days.ago)
  end
end
