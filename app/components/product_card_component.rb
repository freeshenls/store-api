# frozen_string_literal: true

class ProductCardComponent < ViewComponent::Base
  def initialize(
    product,
    locale: I18n.locale,
    price: product.master.default_price,
    additional_classes: '',
    home_collection: false
  )
    @product = product
    @locale = locale
    @price = price
    @additional_classes = additional_classes
    @home_collection = home_collection
  end

  attr_reader :product, :locale, :price, :additional_classes

  def main_image
    product.gallery.images.first
  end

  def display_price
    @display_price ||= price&.money
  end

  # Check if there are any active volume/tiered prices for the master variant
  def has_tiered_pricing?
    product.master.volume_prices.any? || product.master.model_volume_prices.any?
  end

  # Calculate the minimum possible unit price considering base price and volume pricing discounts
  def lowest_price_amount
    all_computed_prices.min
  end

  # Returns Spree::Money instance for the lowest calculated price
  def lowest_price_money
    @lowest_price_money ||= Spree::Money.new(lowest_price_amount, currency: price.currency)
  end

  # Calculate the maximum possible unit price considering base price and volume pricing discounts
  def highest_price_amount
    all_computed_prices.max
  end

  # Returns Spree::Money instance for the highest calculated price
  def highest_price_money
    @highest_price_money ||= Spree::Money.new(highest_price_amount, currency: price.currency)
  end

  private

  def all_computed_prices
    @all_computed_prices ||= begin
      base_amount = price&.amount.to_f
      vps = product.master.volume_prices + product.master.model_volume_prices
      guest_vps = vps.select { |vp| vp.role_id.nil? }

      prices = [base_amount]
      guest_vps.each do |vp|
        val = case vp.discount_type
              when 'price'
                vp.amount.to_f
              when 'dollar'
                base_amount - vp.amount.to_f
              when 'percent'
                base_amount * (1.0 - vp.amount.to_f)
              else
                base_amount
              end
        prices << val
      end
      prices
    end
  end
end
