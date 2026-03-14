class Event < ApplicationRecord
  belongs_to :group
  belongs_to :created_by, class_name: "User"
  has_many :event_occurrences, dependent: :destroy

  validates :title, presence: true
  validates :recurrence_type, presence: true, inclusion: { in: %w[none daily weekly monthly] }
  validates :quorum, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :active, -> { where(is_active: true) }
  scope :recurring, -> { where.not(recurrence_type: "none") }

  # Returns an IceCube::Schedule for this event, or nil if non-recurring.
  # The schedule is serialized as JSON in the recurrence_rule column.
  def schedule
    return nil if recurrence_type == "none" || recurrence_rule.blank?
    IceCube::Schedule.from_hash(JSON.parse(recurrence_rule))
  end

  def schedule=(ice_cube_schedule)
    self.recurrence_rule = ice_cube_schedule&.to_hash&.to_json
  end

  # Returns the next n occurrence times after a given time.
  def next_occurrences(n, after: Time.current)
    schedule&.next_occurrences(n, after) || []
  end

  # Builds an IceCube::Schedule from a start_time and recurrence params.
  # Saves it to recurrence_rule.
  #
  # recurrence_type: "weekly" | "monthly"
  # For "weekly": pass day_of_week (e.g. :thursday)
  # For "monthly": pass nth_weekday: { day: :thursday, n: 3 }
  #                or day_of_month: 17
  def build_schedule(start_time, **opts)
    s = IceCube::Schedule.new(start_time)

    rule = case recurrence_type
    when "daily"
      IceCube::Rule.daily
    when "weekly"
      IceCube::Rule.weekly.day(opts[:day_of_week] || start_time.strftime("%A").downcase.to_sym)
    when "monthly"
      if opts[:nth_weekday]
        day  = opts[:nth_weekday][:day]
        n    = opts[:nth_weekday][:n]
        IceCube::Rule.monthly.day_of_week(day => [ n ])
      else
        dom = opts[:day_of_month] || start_time.day
        IceCube::Rule.monthly.day_of_month(dom)
      end
    end

    s.add_recurrence_rule(rule) if rule
    self.schedule = s
    s
  end
end
