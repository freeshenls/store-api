class InquiryModalComponent < ViewComponent::Base
  def initialize(product:)
    @product = product
  end
end
