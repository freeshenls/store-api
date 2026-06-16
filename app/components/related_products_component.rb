class RelatedProductsComponent < ViewComponent::Base
  def initialize(related_products:)
    @related_products = related_products || []
  end
end
