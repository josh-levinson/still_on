class TwilioWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :require_twilio_signature

  STOP_KEYWORDS = %w[STOP STOPALL UNSUBSCRIBE CANCEL END QUIT].freeze
  # Twilio lifts its carrier-level block on these, so we must lift ours too.
  START_KEYWORDS = %w[START YES UNSTOP].freeze

  # Message statuses that mean the text never reached the phone.
  FAILED_STATUSES = %w[failed undelivered].freeze

  def sms
    from = normalize_phone(params[:From])
    body = params[:Body].to_s.strip.upcase

    if STOP_KEYWORDS.include?(body)
      SmsOptOut.opt_out!(from)
    elsif START_KEYWORDS.include?(body)
      SmsOptOut.opt_in!(from)
    end

    head :ok
  end

  # Status callback for messages we send (see SmsService#status_callback).
  # Carrier-side failures only show up here — the API call itself succeeded.
  def status
    if FAILED_STATUSES.include?(params[:MessageStatus])
      notify_honeybadger(
        "SMS #{params[:MessageStatus]} (Twilio error #{params[:ErrorCode]})",
        error_class: "Twilio::DeliveryFailure",
        code: params[:ErrorCode],
        context: { message_sid: params[:MessageSid], message_status: params[:MessageStatus] }
      )
    end

    head :ok
  end

  # Twilio Console → Monitor → Errors → Webhook. Account-wide errors and warnings,
  # including ones our code never sees (failed inbound webhooks, 10DLC problems).
  # Only the code and SID are forwarded: the full payload can include phone
  # numbers and message bodies, and the SID is enough to look it up in Twilio.
  def debugger
    payload = debugger_payload
    code = payload["error_code"].to_s

    # Message delivery errors (30xxx) are already reported via #status.
    unless code.start_with?("30")
      notify_honeybadger(
        "Twilio #{params[:Level].to_s.downcase} #{code}",
        error_class: "Twilio::DebuggerAlert",
        code: code,
        context: { level: params[:Level], sid: params[:Sid], resource_sid: payload["resource_sid"] }
      )
    end

    head :ok
  end

  # Callback URL for Usage Triggers (Twilio Console → Usage → Triggers), e.g. a
  # daily cap on SMS spend. Fingerprinted by usage category so each kind of
  # trigger gets its own Honeybadger error.
  def usage
    category = params[:UsageCategory].to_s

    Honeybadger.notify(
      "Twilio usage trigger: #{category} reached #{params[:CurrentValue]} (limit #{params[:TriggerValue]} #{params[:TriggerBy]})",
      error_class: "Twilio::UsageTrigger",
      fingerprint: "Twilio::UsageTrigger-#{category}",
      context: {
        usage_category: category,
        trigger_by: params[:TriggerBy],
        trigger_value: params[:TriggerValue],
        current_value: params[:CurrentValue],
        recurring: params[:Recurring],
        trigger_sid: params[:UsageTriggerSid]
      }
    )

    head :ok
  end

  private

  def debugger_payload
    JSON.parse(params[:Payload].to_s)
  rescue JSON::ParserError
    {}
  end

  def require_twilio_signature
    head :forbidden unless valid_twilio_request?
  end

  # Fingerprinting by error code gives each kind of failure its own Honeybadger
  # error, so a spike in one code stands out instead of blending together.
  def notify_honeybadger(message, error_class:, code:, context:)
    Honeybadger.notify(
      message,
      error_class: error_class,
      fingerprint: "#{error_class}-#{code}",
      context: context.merge(twilio_code: code)
    )
  end

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
