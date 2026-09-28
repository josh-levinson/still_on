class ApplicationMailer < ActionMailer::Base
  default from: Rails.application.credentials.dig(:email, :from) || "StillOn <noreply@stillon.app>"
  layout "mailer"
end
