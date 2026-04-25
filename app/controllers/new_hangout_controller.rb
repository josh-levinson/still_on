class NewHangoutController < ApplicationController
  layout "onboarding"
  before_action :authenticate_user!

  CADENCES = %w[none weekly monthly].freeze

  def name
    @step = 1
    @total_steps = 3
  end

  def submit_name
    hangout_name = params[:hangout_name].to_s.strip

    if hangout_name.blank?
      flash.now[:error] = "Please name your hangout."
      @step = 1
      @total_steps = 3
      render :name, status: :unprocessable_entity
      return
    end

    session[:nh_hangout_name] = hangout_name
    session[:nh_time_zone]    = rails_zone_from_iana(params[:time_zone])
    redirect_to new_hangout_date_path
  end

  def date_step
    return redirect_to new_hangout_path unless session[:nh_hangout_name].present?
    @step = 2
    @total_steps = 3
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
      @total_steps = 3
      today = Date.today
      days_until_friday = (5 - today.wday) % 7
      days_until_friday = 7 if days_until_friday.zero?
      @this_friday = today + days_until_friday
      @next_friday = @this_friday + 7
      render :date_step, status: :unprocessable_entity
      return
    end

    session[:nh_date] = date.to_s
    session[:nh_time] = sanitize_time(params[:time])
    redirect_to new_hangout_cadence_path
  end

  def cadence
    return redirect_to new_hangout_path unless session[:nh_date].present?
    @step = 3
    @total_steps = 3
    date = Date.parse(session[:nh_date])
    @day_name      = date.strftime("%A")
    @monthly_label = "#{nth_weekday_n(date).ordinalize} #{@day_name}"
  end

  def submit_cadence
    cadence = params[:cadence].to_s

    unless CADENCES.include?(cadence)
      flash.now[:error] = "Please choose how often."
      @step = 3
      @total_steps = 3
      render :cadence, status: :unprocessable_entity
      return
    end

    session[:nh_cadence] = cadence

    _group, occurrence = create_hangout!(current_user)
    session[:nh_occurrence_id] = occurrence.id.to_s

    redirect_to new_hangout_invite_path
  end

  def invite
    occurrence_id = session[:nh_occurrence_id]
    redirect_to dashboard_path and return unless occurrence_id

    @occurrence   = EventOccurrence.find(occurrence_id)
    @hangout_name = session[:nh_hangout_name]
    @cadence      = session[:nh_cadence]
    @date         = Date.parse(session[:nh_date])
    @invite_url   = guest_rsvp_url(@occurrence.invite_token)
  end

  private

  def rails_zone_from_iana(iana_name)
    return current_user.time_zone.presence || "UTC" if iana_name.blank?
    ActiveSupport::TimeZone::MAPPING.key(iana_name) || current_user.time_zone.presence || "UTC"
  end

  def sanitize_time(raw)
    return "19:00" unless raw.to_s.match?(/\A\d{1,2}:\d{2}\z/)
    h, m = raw.split(":").map(&:to_i)
    return "19:00" unless (0..23).cover?(h) && (0..59).cover?(m)
    format("%02d:%02d", h, m)
  end

  def nth_weekday_n(date)
    ((date.day - 1) / 7) + 1
  end

  def create_hangout!(user)
    hangout_name = session[:nh_hangout_name]
    date         = Date.parse(session[:nh_date])
    cadence      = session[:nh_cadence]
    time_zone    = session[:nh_time_zone].presence || user.time_zone.presence || "UTC"
    hour, min    = (session[:nh_time].presence || "19:00").split(":").map(&:to_i)
    start_time   = Time.use_zone(time_zone) { Time.zone.local(date.year, date.month, date.day, hour, min, 0) }
    end_time     = start_time + 2.hours

    slug = hangout_name.parameterize.presence || "hangout"
    if Group.where(slug: slug).exists?
      slug = "#{slug}-#{SecureRandom.hex(3)}"
    end

    group = Group.create!(
      name:       hangout_name,
      slug:       slug,
      is_private: false,
      created_by: user,
      time_zone:  time_zone
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
