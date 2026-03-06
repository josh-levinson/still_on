class SmsService
  FROM_NUMBER = Rails.application.credentials.dig(:twilio, :from_number) ||
                ENV["TWILIO_FROM_NUMBER"]

  def self.send_message(to:, body:)
    new.send_message(to:, body:)
  end

  def send_message(to:, body:)
    client.messages.create(
      from: FROM_NUMBER,
      to: to,
      body: body
    )
  rescue Twilio::REST::RestError => e
    Rails.logger.error("[SmsService] Failed to send SMS to #{to}: #{e.message}")
    raise
  end

  private

  def client
    Twilio::REST::Client.new
  end
end
