# Rate limits for endpoints that send SMS or check OTP codes.
#
# Limits share a scope across controllers so an attacker can't multiply them by
# hopping between onboarding, sign-in, account claim, and RSVP-resend endpoints.
module SmsThrottling
  extend ActiveSupport::Concern

  SENDS_PER_IP_PER_HOUR    = 20
  SENDS_PER_PHONE_PER_HOUR = 5
  VERIFIES_PER_IP_PER_10_MIN = 30

  # rate_limit captures its store when the class loads. Resolve Rails.cache per
  # request instead so tests can swap in a real store (the test env uses null_store).
  module Store
    def self.increment(...) = Rails.cache.increment(...)
  end

  class_methods do
    # `phone` is a lambda returning the destination phone for the request.
    def throttle_sms_sends(only:, phone:)
      rate_limit to: SENDS_PER_IP_PER_HOUR, within: 1.hour, only: only,
        scope: "sms-send", name: "ip", store: Store, with: :sms_rate_limited
      rate_limit to: SENDS_PER_PHONE_PER_HOUR, within: 1.hour, only: only,
        by: -> { normalized_phone_key(instance_exec(&phone)) },
        scope: "sms-send", name: "phone", store: Store, with: :sms_rate_limited
    end

    def throttle_otp_verifies(only:)
      rate_limit to: VERIFIES_PER_IP_PER_10_MIN, within: 10.minutes, only: only,
        scope: "otp-verify", store: Store, with: :sms_rate_limited
    end
  end

  private

  # Fall back to the IP so invalid/blank phones don't all share one bucket.
  def normalized_phone_key(raw)
    raw.to_s.gsub(/\D/, "").last(10).presence || request.remote_ip
  end

  def sms_rate_limited
    redirect_back_or_to root_path, alert: "Too many attempts. Please wait a while and try again."
  end
end
