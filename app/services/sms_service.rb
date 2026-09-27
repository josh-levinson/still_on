class SmsService
  # Carriers expect every message to identify the sender.
  PREFIX = "StillOn: ".freeze

  def self.send_message(to:, body:)
    new.send_message(to:, body:)
  end

  def initialize(client: nil)
    @client = client
  end

  def send_message(to:, body:)
    client.messages.create(
      from: from_number,
      to: to,
      body: branded(body)
    )
  rescue Twilio::REST::RestError => e
    Rails.logger.error("[SmsService] Failed to send SMS to #{to}: #{e.message}")
    raise
  end

  private

  def branded(body)
    body.start_with?(PREFIX) ? body : "#{PREFIX}#{body}"
  end

  def from_number
    Rails.application.credentials.dig(:twilio, :from_number) || ENV["TWILIO_FROM_NUMBER"]
  end

  def client
    @client ||= Twilio::REST::Client.new
  end
end
