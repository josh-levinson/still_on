class ApplicationMailer < ActionMailer::Base
  default from: Rails.application.credentials.dig(:email, :from) || "StillOn <noreply@stillonapp.com>"
  layout "mailer"
end
