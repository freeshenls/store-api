class Product < ApplicationRecord
  has_many_attached :images
  has_many :inquiries, dependent: :destroy

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  private

  def generate_slug
    if slug.blank? && title.present?
      self.slug = title.parameterize
    end
  end
end
