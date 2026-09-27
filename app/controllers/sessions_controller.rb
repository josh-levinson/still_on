class SessionsController < ApplicationController
  include OtpVerification
  include SmsThrottling

  layout "onboarding"

  throttle_sms_sends only: :submit_phone, phone: -> { params[:phone] }
  throttle_sms_sends only: :resend_otp,   phone: -> { session[:signin_phone] }
  throttle_otp_verifies only: :submit_verify

  before_action :redirect_if_signed_in, only: [ :phone, :verify ]

  def phone
  end

  def submit_phone
    phone = params[:phone].to_s.gsub(/\D/, "")

    if phone.length < 10
      flash.now[:error] = "Please enter a valid 10-digit phone number."
      render :phone, status: :unprocessable_entity
      return
    end

    unless User.exists?(phone_number: phone)
      flash.now[:error] = "No account found with that number. Did you mean to get started?"
      render :phone, status: :unprocessable_entity
      return
    end

    session[:signin_phone] = phone
    session[:signin_otp], session[:signin_otp_expires_at] = deliver_otp(phone, log_tag: "SignIn")
    redirect_to sign_in_verify_path
  end

  def verify
    redirect_to sign_in_path unless session[:signin_phone]
  end

  def submit_verify
    phone  = session[:signin_phone]
    result = check_otp(phone: phone, code: params[:code].to_s.strip,
      stored: session[:signin_otp], expires_at: session[:signin_otp_expires_at])

    if result == :ok
      session.delete(:signin_otp)
      session.delete(:signin_otp_expires_at)
      user = User.find_by(phone_number: phone)

      if user
        session.delete(:signin_phone)
        session[:user_id] = user.id
        redirect_to dashboard_path, notice: "Welcome back, #{user.first_name}!"
      else
        flash.now[:error] = "No account found for that number."
        render :verify, status: :unprocessable_entity
      end
    else
      flash.now[:error] = otp_error_message(result)
      render :verify, status: :unprocessable_entity
    end
  end

  def resend_otp
    phone = session[:signin_phone]
    redirect_to sign_in_path and return unless phone

    session[:signin_otp], session[:signin_otp_expires_at] = deliver_otp(phone, log_tag: "SignIn")
    redirect_to sign_in_verify_path, notice: "Code resent!"
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: "You've been signed out."
  end

  private

  def redirect_if_signed_in
    redirect_to dashboard_path if user_signed_in?
  end
end
