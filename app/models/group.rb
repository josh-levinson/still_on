class Group < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  has_many :group_memberships, dependent: :destroy
  has_many :members, through: :group_memberships, source: :user
  has_many :events, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :is_private, inclusion: { in: [true, false] }

  before_validation :generate_slug, on: :create

  private

  def generate_slug
    return if slug.present?

    self.slug = name.parameterize if name.present?
  end
end
