class TwilioWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  STOP_KEYWORDS = %w[STOP STOPALL UNSUBSCRIBE CANCEL END QUIT].freeze

  def sms
    unless valid_twilio_request?
      head :forbidden
      return
    end

    from = normalize_phone(params[:From])
    body = params[:Body].to_s.strip.upcase

    if STOP_KEYWORDS.include?(body)
      SmsOptOut.opt_out!(from)
    end

    head :ok
  end

  private

  # Strip country code prefix to match how phone numbers are stored (10 digits, no +1)
  def normalize_phone(phone)
    phone.to_s.gsub(/\A\+1/, "").gsub(/\D/, "")
  end

  def valid_twilio_request?
    return true if Rails.env.test?

    validator = Twilio::Security::RequestValidator.new(
      Rails.application.credentials.dig(:twilio, :auth_token) || ENV["TWILIO_AUTH_TOKEN"]
    )
    validator.validate(
      request.url,
      request.POST,
      request.headers["X-Twilio-Signature"]
    )
  end
end
