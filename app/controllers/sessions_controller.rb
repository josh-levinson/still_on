class SessionsController < ApplicationController
  layout "onboarding"

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

    otp = rand(100_000..999_999).to_s
    Rails.cache.write("otp:#{phone}", otp, expires_in: 10.minutes)

    begin
      SmsService.send_message(to: "+1#{phone}", body: "Your StillOn code is #{otp}. It expires in 10 minutes.")
    rescue => e
      Rails.logger.error("[SignIn] OTP send failed: #{e.message}")
    end

    session[:signin_phone] = phone
    redirect_to sign_in_verify_path
  end

  def verify
    redirect_to sign_in_path unless session[:signin_phone]
  end

  def submit_verify
    phone  = session[:signin_phone]
    code   = params[:code].to_s.strip
    stored = Rails.cache.read("otp:#{phone}")

    if stored && code == stored
      Rails.cache.delete("otp:#{phone}")
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
      flash.now[:error] = "That code didn't match. Please try again."
      render :verify, status: :unprocessable_entity
    end
  end

  def resend_otp
    phone = session[:signin_phone]
    redirect_to sign_in_path and return unless phone

    otp = rand(100_000..999_999).to_s
    Rails.cache.write("otp:#{phone}", otp, expires_in: 10.minutes)

    begin
      SmsService.send_message(to: "+1#{phone}", body: "Your StillOn code is #{otp}. It expires in 10 minutes.")
    rescue => e
      Rails.logger.error("[SignIn] OTP resend failed: #{e.message}")
    end

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
