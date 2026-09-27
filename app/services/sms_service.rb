class SmsService
  # Carriers expect every message to identify the sender.
  PREFIX = "StillOn: ".freeze

  def self.send_message(to:, body:)
    new.send_message(to:, body:)
  end

  # For log lines: keeps the last four digits so a number can be matched up
  # without writing the whole thing to the logs.
  def self.mask(phone)
    "***#{phone.to_s.gsub(/\D/, "").last(4)}"
  end

  def initialize(client: nil)
    @client = client
  end

  # Failures are reported to the error tracker here and then re-raised, so
  # callers decide whether to fall back or carry on without reporting again.
  def send_message(to:, body:)
    client.messages.create(
      from: from_number,
      to: to,
      body: branded(body),
      **status_callback
    )
  rescue StandardError => e
    Rails.logger.error("[SmsService] Failed to send SMS to #{self.class.mask(to)}: #{e.message}")
    Rails.error.report(e, handled: true, context: { twilio_code: e.try(:code) })
    raise
  end

  private

  def branded(body)
    body.start_with?(PREFIX) ? body : "#{PREFIX}#{body}"
  end

  # Twilio posts delivery results (including carrier failures that happen after
  # the API call succeeds) to TwilioWebhooksController#status. Only turned on
  # where Twilio can reach us — see config.x.twilio_status_callbacks.
  def status_callback
    return {} unless Rails.configuration.x.twilio_status_callbacks

    url_options = Rails.application.config.action_mailer.default_url_options
    { status_callback: Rails.application.routes.url_helpers.twilio_status_webhook_url(**url_options, protocol: "https") }
  end

  def from_number
    Rails.application.credentials.dig(:twilio, :from_number) || ENV["TWILIO_FROM_NUMBER"]
  end

  def client
    @client ||= Twilio::REST::Client.new
  end
end
