class OnboardingController < ApplicationController
  layout "onboarding"

  CADENCES = %w[none weekly monthly].freeze

  def splash
    redirect_to dashboard_path if user_signed_in?
  end

  def name
    @step = 1
  end

  def submit_name
    first_name    = params[:first_name].to_s.strip
    hangout_name  = params[:hangout_name].to_s.strip

    if first_name.blank? || hangout_name.blank?
      flash.now[:error] = "Please fill in both fields."
      @step = 1
      render :name, status: :unprocessable_entity
      return
    end

    session[:ob_first_name]   = first_name
    session[:ob_hangout_name] = hangout_name
    redirect_to onboarding_date_path
  end

  def date_step
    @step = 2
    today = Date.today
    days_until_friday = (5 - today.wday) % 7
    days_until_friday = 7 if days_until_friday.zero?
    @this_friday = today + days_until_friday
    @next_friday = @this_friday + 7
  end

  def submit_date
    date_str = params[:date].to_s.strip

    begin
      date = Date.parse(date_str)
      raise ArgumentError if date < Date.today
    rescue ArgumentError, TypeError
      flash.now[:error] = "Please pick a valid future date."
      @step = 2
      today = Date.today
      days_until_friday = (5 - today.wday) % 7
      days_until_friday = 7 if days_until_friday.zero?
      @this_friday = today + days_until_friday
      @next_friday = @this_friday + 7
      render :date_step, status: :unprocessable_entity
      return
    end

    session[:ob_date] = date.to_s
    redirect_to onboarding_cadence_path
  end

  def cadence
    @step = 3
    if session[:ob_date].present?
      date = Date.parse(session[:ob_date])
      @day_name      = date.strftime("%A")
      @monthly_label = "#{nth_weekday_n(date).ordinalize} #{@day_name}"
    end
  end

  def submit_cadence
    cadence = params[:cadence].to_s

    unless CADENCES.include?(cadence)
      flash.now[:error] = "Please choose how often."
      @step = 3
      render :cadence, status: :unprocessable_entity
      return
    end

    session[:ob_cadence] = cadence

    # Create user without phone number first
    user = create_user_without_phone!
    session[:user_id] = user.id

    _group, occurrence = create_hangout!(user)

    session[:ob_occurrence_id] = occurrence.id.to_s
    redirect_to onboarding_phone_path
  end

  def phone
    return redirect_to dashboard_path if current_user&.phone_verified_at.present?
    return redirect_to onboarding_splash_path unless session[:ob_occurrence_id]
    @step = 4
  end

  def submit_phone
    phone = params[:phone].to_s.gsub(/\D/, "")

    if phone.length < 10
      flash.now[:error] = "Please enter a valid 10-digit phone number."
      @step = 4
      render :phone, status: :unprocessable_entity
      return
    end

    otp = rand(100_000..999_999).to_s
    Rails.cache.write("otp:#{phone}", otp, expires_in: 10.minutes)

    begin
      SmsService.send_message(to: "+1#{phone}", body: "Your StillOn code is #{otp}. It expires in 10 minutes.")
    rescue => e
      Rails.logger.error("[Onboarding] OTP send failed: #{e.message}")
    end

    session[:ob_phone] = phone
    redirect_to onboarding_verify_path
  end

  def verify
    redirect_to onboarding_phone_path unless session[:ob_phone]
    @step = 5
  end

  def submit_verify
    phone = session[:ob_phone]
    code  = params[:code].to_s.strip
    stored = Rails.cache.read("otp:#{phone}")

    if stored && code == stored
      Rails.cache.delete("otp:#{phone}")

      # Update the user's phone number and mark as verified
      if current_user
        current_user.update!(phone_number: phone, phone_verified_at: Time.current)
      end

      redirect_to onboarding_invite_path
    else
      flash.now[:error] = "That code didn't match. Please try again."
      @step = 5
      render :verify, status: :unprocessable_entity
    end
  end

  def resend_otp
    phone = session[:ob_phone]
    redirect_to onboarding_phone_path and return unless phone

    otp = rand(100_000..999_999).to_s
    Rails.cache.write("otp:#{phone}", otp, expires_in: 10.minutes)

    begin
      SmsService.send_message(to: "+1#{phone}", body: "Your StillOn code is #{otp}. It expires in 10 minutes.")
    rescue => e
      Rails.logger.error("[Onboarding] OTP resend failed: #{e.message}")
    end

    redirect_to onboarding_verify_path, notice: "Code resent!"
  end

  def invite
    occurrence_id = session[:ob_occurrence_id]
    redirect_to onboarding_splash_path and return unless occurrence_id

    @occurrence   = EventOccurrence.find(occurrence_id)
    @hangout_name = session[:ob_hangout_name]
    @first_name   = session[:ob_first_name]
    @cadence      = session[:ob_cadence]
    @date         = Date.parse(session[:ob_date])
    @invite_url   = guest_rsvp_url(@occurrence.invite_token)
    @step = 6
  end

  private

  def nth_weekday_n(date)
    ((date.day - 1) / 7) + 1
  end

  def create_user_without_phone!
    first_name = session[:ob_first_name]

    User.create!(first_name: first_name)
  end

  def create_hangout!(user)
    hangout_name = session[:ob_hangout_name]
    date         = Date.parse(session[:ob_date])
    cadence      = session[:ob_cadence]
    start_time   = date.to_time.change(hour: 19)
    end_time     = start_time + 2.hours

    slug = hangout_name.parameterize.presence || "hangout"
    if Group.where(slug: slug).exists?
      slug = "#{slug}-#{SecureRandom.hex(3)}"
    end

    group = Group.create!(
      name:       hangout_name,
      slug:       slug,
      is_private: false,
      created_by: user
    )

    GroupMembership.create!(group: group, user: user)

    event = Event.create!(
      title:           hangout_name,
      group:           group,
      created_by:      user,
      recurrence_type: cadence,
      is_active:       true
    )

    if cadence != "none"
      schedule_opts = if cadence == "monthly"
        { nth_weekday: { day: date.strftime("%A").downcase.to_sym, n: nth_weekday_n(date) } }
      else
        {}
      end
      event.build_schedule(start_time, **schedule_opts)
      event.save!
    end

    occurrence = EventOccurrence.create!(
      event:      event,
      start_time: start_time,
      end_time:   end_time,
      status:     "scheduled"
    )

    [ group, occurrence ]
  end
end
