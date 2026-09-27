class Group < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  has_many :group_memberships, dependent: :destroy
  has_many :members, through: :group_memberships, source: :user
  has_many :events, dependent: :destroy
  has_many :guest_group_subscriptions, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :is_private, inclusion: { in: [ true, false ] }
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
  validates :reminder_days_before, inclusion: { in: 1..7 }
  validate :paused_until_in_future, if: -> { paused_until.present? && will_save_change_to_paused_until? }

  scope :public_groups, -> { where(is_private: false) }

  before_validation :generate_slug, on: :create

  def to_param
    slug
  end

  def member?(user)
    return false unless user
    members.include?(user)
  end

  def organizer?(user)
    return false unless user
    return true if created_by == user
    group_memberships.organizers.exists?(user_id: user.id)
  end

  # A paused group generates no new occurrences and sends no automated
  # reminders. With a paused_until date, the pause lifts automatically at the
  # start of that day in the group's time zone; without one it lasts until
  # an organizer resumes it.
  def pause!(until_date: nil)
    update!(paused_at: Time.current, paused_until: until_date)
  end

  def resume!
    update!(paused_at: nil, paused_until: nil)
  end

  def paused?
    paused_during?(Time.current)
  end

  def paused_during?(time)
    return false if paused_at.nil?
    resumes_at.nil? || time < resumes_at
  end

  def resumes_at
    paused_until&.in_time_zone(time_zone)
  end

  private

  def paused_until_in_future
    if paused_until <= Time.current.in_time_zone(time_zone).to_date
      errors.add(:paused_until, "must be in the future")
    end
  end

  def generate_slug
    return if slug.present?

    self.slug = name.parameterize if name.present?
  end
end
