class ProductPriceTableComponent < ViewComponent::Base
  def initialize(price_grid:, setup_prices:, currency_sym: "$")
    @price_grid = price_grid || []
    @setup_prices = setup_prices || []
    @currency_sym = currency_sym
  end
end
