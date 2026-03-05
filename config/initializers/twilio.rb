Twilio.configure do |config|
  config.account_sid = Rails.application.credentials.dig(:twilio, :account_sid) ||
                       ENV["TWILIO_ACCOUNT_SID"]
  config.auth_token  = Rails.application.credentials.dig(:twilio, :auth_token) ||
                       ENV["TWILIO_AUTH_TOKEN"]
end
