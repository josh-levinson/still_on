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
        Rails.logger.warn("[notify] SMS failed for #{phone}, trying email: #{e.message}")
      end
    end

    return if email.blank?

    EventMailer.notification(to: email, subject: subject || "StillOn notification", body: body).deliver_now
  end
end
