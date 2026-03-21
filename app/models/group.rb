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

  private

  def generate_slug
    return if slug.present?

    self.slug = name.parameterize if name.present?
  end
end
