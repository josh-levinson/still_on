# Email goes out through Resend's HTTPS API (Railway blocks outbound SMTP).
# Production sets config.action_mailer.delivery_method = :resend.
Resend.api_key = ENV["RESEND_API_KEY"]
