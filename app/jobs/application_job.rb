class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  private

  # Try SMS first; fall back to email if SMS fails or phone is unavailable.
  def notify(phone: nil, email: nil, subject: nil, body:)
    if phone.present? && !SmsOptOut.opted_out?(phone)
      begin
        SmsService.send_message(to: phone, body: body)
        return
      rescue Twilio::REST::RestError => e
        # SmsService has already reported the error.
        Rails.logger.warn("[notify] SMS failed for #{SmsService.mask(phone)}, trying email: #{e.message}")
      end
    end

    return if email.blank?

    EventMailer.notification(to: email, subject: subject || "StillOn notification", body: body).deliver_now
  end

  # Ping a Honeybadger check-in so we get alerted if a scheduled job stops running.
  # The check-in ID comes from HONEYBADGER_CHECKIN_<NAME>; no-op when unset.
  def check_in(name)
    id = ENV["HONEYBADGER_CHECKIN_#{name.to_s.upcase}"]
    Honeybadger.check_in(id) if id.present?
  end
end
