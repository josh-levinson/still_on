class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :created_groups, class_name: "Group", foreign_key: :created_by_id, dependent: :destroy
  has_many :created_events, class_name: "Event", foreign_key: :created_by_id, dependent: :destroy
  has_many :group_memberships, dependent: :destroy
  has_many :groups, through: :group_memberships
  has_many :rsvps, dependent: :destroy

  validates :username, uniqueness: true, allow_nil: true
  validates :email, presence: true, uniqueness: true

  def full_name
    [first_name, last_name].compact.join(" ").presence || username || email
  end
end
