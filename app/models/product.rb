class Product < ApplicationRecord
  has_many_attached :images

  validates :title, presence: true
  validates :guid, presence: true
  validates :slug, presence: true

  before_validation :generate_slug, on: :create

  def badge
    nil
  end

  def old_price
    nil
  end

  def product_detail
    description
  end


  private

  def generate_slug
    if slug.blank? && title.present?
      self.slug = title.to_s.parameterize.presence || guid.to_s.downcase
    end
  end
end

