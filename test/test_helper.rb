require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  minimum_coverage line: 100, branch: 100
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require_relative "support/sessions_controller"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    parallelize_setup do |worker|
      SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
    end

    parallelize_teardown do |worker|
      SimpleCov.result
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # --- Factory helpers ---
    # These create the full model hierarchy without relying on UUID fixtures.

    def build_user(attrs = {})
      User.new({
        first_name: "Test",
        last_name: "User",
        username: "user_#{SecureRandom.hex(4)}",
        phone_number: "+1555#{rand(1_000_000..9_999_999)}"
      }.merge(attrs))
    end

    def create_user(attrs = {})
      build_user(attrs).tap(&:save!)
    end

    def create_group(user, attrs = {})
      Group.create!({
        name: "Test Group #{SecureRandom.hex(4)}",
        created_by: user,
        is_private: false
      }.merge(attrs))
    end

    def create_event(group, user, attrs = {})
      Event.create!({
        title: "Test Event",
        group: group,
        created_by: user,
        recurrence_type: "weekly"
      }.merge(attrs))
    end

    def create_occurrence(event, attrs = {})
      EventOccurrence.create!({
        event: event,
        start_time: 1.week.from_now,
        end_time: 1.week.from_now + 2.hours,
        status: "scheduled"
      }.merge(attrs))
    end

    def create_rsvp(occurrence, attrs = {})
      Rsvp.create!({
        event_occurrence: occurrence,
        status: "attending",
        guest_name: "Guest Person",
        guest_count: 0
      }.merge(attrs))
    end
  end
end

module ActiveSupport
  class TestCase
    # Swap in a memory cache store for the duration of the block, then restore.
    # Useful for controller tests that exercise OTP flows (the test env uses null_store).
    def with_memory_cache
      original = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      yield
    ensure
      Rails.cache = original
    end
  end
end

module ActionDispatch
  class IntegrationTest
    # Sign in a user for controller/integration tests via the test backdoor route.
    # This makes a real POST that sets the session cookie, which persists to
    # subsequent requests (required because CookieStore re-decodes the cookie
    # on every request, ignoring in-memory session mutations).
    def sign_in(user)
      post test_sign_in_path, params: { user_id: user.id }
    end
  end
end
