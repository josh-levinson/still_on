class EventMailer < ApplicationMailer
  def notification(to:, subject:, body:)
    @body = body
    mail(to: to, subject: subject)
  end
end
