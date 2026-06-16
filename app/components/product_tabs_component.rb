class ProductTabsComponent < ViewComponent::Base
  def initialize(description:, product_shipping_html:, sales_flyer_url:)
    @description = description
    @product_shipping_html = product_shipping_html
    @sales_flyer_url = sales_flyer_url
  end
end
