class ProductCardComponent < ViewComponent::Base
  def initialize(product:, hide_category: false)
    @product = product
    @hide_category = hide_category
  end

  def product_link
    "/products/#{@product.guid}/#{@product.slug}"
  end
end
