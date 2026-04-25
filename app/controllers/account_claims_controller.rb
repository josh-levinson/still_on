class AccountClaimsController < ApplicationController
  layout "onboarding"

  before_action :redirect_if_signed_in

  def new
  end

  def submit_phone
    first_name = params[:first_name].to_s.strip
    phone      = params[:phone].to_s.gsub(/\D/, "")

    if first_name.blank?
      flash.now[:error] = "Please enter your name."
      render :new, status: :unprocessable_entity
      return
    end

    if phone.length < 10
      flash.now[:error] = "Please enter a valid 10-digit phone number."
      render :new, status: :unprocessable_entity
      return
    end

    if User.exists?(phone_number: phone)
      redirect_to sign_in_path, notice: "You already have an account. Sign in here."
      return
    end

    otp = rand(100_000..999_999).to_s

    begin
      SmsService.send_message(to: "+1#{phone}", body: "Your StillOn code is #{otp}. It expires in 10 minutes.")
    rescue => e
      Rails.logger.error("[AccountClaim] OTP send failed: #{e.message}")
    end

    session[:claim_first_name]     = first_name
    session[:claim_phone]          = phone
    session[:claim_otp]            = otp
    session[:claim_otp_expires_at] = 10.minutes.from_now.to_i
    redirect_to account_claim_verify_path
  end

  def verify
    redirect_to new_account_claim_path unless session[:claim_phone]
  end

  def submit_verify
    phone      = session[:claim_phone]
    first_name = session[:claim_first_name]
    code       = params[:code].to_s.strip
    stored     = session[:claim_otp]
    expires_at = session[:claim_otp_expires_at].to_i

    if stored && code == stored && Time.current.to_i < expires_at
      session.delete(:claim_otp)
      session.delete(:claim_otp_expires_at)
      session.delete(:claim_phone)
      session.delete(:claim_first_name)

      user = User.create!(first_name: first_name)
      user.update!(phone_number: phone, phone_verified_at: Time.current)

      session[:user_id] = user.id
      redirect_to dashboard_path, notice: "Welcome to StillOn, #{first_name}!"
    else
      flash.now[:error] = "That code didn't match. Please try again."
      render :verify, status: :unprocessable_entity
    end
  end

  private

  def redirect_if_signed_in
    redirect_to dashboard_path if user_signed_in?
  end
end
