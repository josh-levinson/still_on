# Generates, sends, and checks SMS one-time codes.
#
# The code itself lives in the (encrypted cookie) session, but wrong-guess counts
# are kept server-side in Rails.cache — a counter in the cookie could be reset by
# replaying an older cookie. Counts are keyed by phone + code, so requesting a new
# code starts fresh (resends are rate limited by SmsThrottling).
module OtpVerification
  extend ActiveSupport::Concern

  MAX_OTP_ATTEMPTS = 5
  OTP_TTL = 10.minutes

  private

  # Sends a new code to the 10-digit `phone` and returns [otp, expires_at].
  # SMS failures are logged, not raised, so the user can still hit "resend".
  # With config.x.otp_sms off (development), the code is only logged.
  def deliver_otp(phone, log_tag:)
    otp = SecureRandom.random_number(100_000..999_999).to_s

    unless Rails.configuration.x.otp_sms
      Rails.logger.info("[#{log_tag}] Code for #{SmsService.mask(phone)}: #{otp} (SMS disabled)")
      return [ otp, OTP_TTL.from_now.to_i ]
    end

    begin
      SmsService.send_message(to: "+1#{phone}", body: "Your verification code is #{otp}. It expires in 10 minutes.")
    rescue => e
      Rails.logger.error("[#{log_tag}] OTP send failed: #{e.message}")
    end

    [ otp, OTP_TTL.from_now.to_i ]
  end

  # Returns :ok, :invalid (wrong or expired), or :locked (too many wrong guesses).
  def check_otp(phone:, code:, stored:, expires_at:)
    return :invalid unless stored && Time.current.to_i < expires_at.to_i

    key = "otp-failures:#{Digest::SHA256.hexdigest("#{phone}:#{stored}")}"
    return :locked if Rails.cache.read(key).to_i >= MAX_OTP_ATTEMPTS

    if ActiveSupport::SecurityUtils.secure_compare(code.to_s, stored)
      Rails.cache.delete(key)
      :ok
    else
      failures = Rails.cache.increment(key, 1, expires_in: OTP_TTL).to_i
      failures >= MAX_OTP_ATTEMPTS ? :locked : :invalid
    end
  end

  def otp_error_message(result)
    if result == :locked
      "Too many incorrect attempts. Please request a new code."
    else
      "That code didn't match. Please try again."
    end
  end
end
