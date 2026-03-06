Twilio.configure do |config|
  credentials = Rails.application.credentials.twilio rescue {}
  config.account_sid = credentials&.dig(:account_sid) || ENV["TWILIO_ACCOUNT_SID"]
  config.auth_token  = credentials&.dig(:auth_token)  || ENV["TWILIO_AUTH_TOKEN"]
end
