# frozen_string_literal: true

Rails.application.config.to_prepare do
  SolidusVolumePricing::Pricer.class_eval do
    # Override price_for_options to integrate with Solidus 4.x
    def price_for_options(pricing_options)
      price = super
      return price unless price

      # Cache the base price amount to avoid infinite recursion when calling variant.price
      @base_price_amount = price.amount
      @current_pricing_options = pricing_options

      extract_options(pricing_options)
      price.amount = computed_price
      price
    ensure
      @base_price_amount = nil
      @current_pricing_options = nil
    end

    # Helper method to get the base price amount without triggering recursion
    def base_price_amount
      @base_price_amount ||= begin
        opts = @current_pricing_options || Spree::Config.default_pricing_options
        Spree::Variant::PriceSelector.new(variant).price_for_options(opts)&.amount
      end
    end

    # Override the methods from the gem to use base_price_amount instead of variant.price
    def computed_price
      base = base_price_amount
      return BigDecimal('0') unless base

      case volume_price&.discount_type
      when 'price'
        volume_price.amount
      when 'dollar'
        base - volume_price.amount
      when 'percent'
        base * (1 - volume_price.amount)
      else
        base
      end
    end

    def computed_earning
      base = base_price_amount
      return BigDecimal('0') unless base

      case volume_price&.discount_type
      when 'price'
        base - volume_price.amount
      when 'dollar'
        volume_price.amount
      when 'percent'
        base - (base * (1 - volume_price.amount))
      else
        0
      end
    end

    def computed_earning_percent
      base = base_price_amount
      return 0 unless base && base > 0

      case volume_price&.discount_type
      when 'price'
        diff = base - volume_price.amount
        diff * 100 / base
      when 'dollar'
        volume_price.amount * 100 / base
      when 'percent'
        volume_price.amount * 100
      else
        0
      end
    end
  end
end
