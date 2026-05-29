class Inquiry < ApplicationRecord
  belongs_to :product
  has_one_attached :artwork

  validates :first_name, :last_name, :company_name, :email, presence: true
end
