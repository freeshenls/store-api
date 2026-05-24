# frozen_string_literal: true

module ProductSearchScopesOverride
  def self.prepended(base)
    base.class_eval do
      # Scope to filter products where lowest possible price is >= val
      add_search_scope :price_min do |val|
        return where(nil) if val.blank?
        val = val.to_f

        # Subquery to calculate the minimum volume price for the master variant
        subquery_min = <<~SQL
          (
            SELECT MIN(
              CASE vp.discount_type
                WHEN 'price' THEN vp.amount
                WHEN 'dollar' THEN (spree_prices.amount - vp.amount)
                WHEN 'percent' THEN (spree_prices.amount * (1.0 - vp.amount))
                ELSE spree_prices.amount
              END
            )
            FROM spree_volume_prices vp
            WHERE (
              vp.variant_id = spree_variants.id
              OR vp.volume_price_model_id IN (
                SELECT vvpm.volume_price_model_id
                FROM spree_variants_volume_price_models vvpm
                WHERE vvpm.variant_id = spree_variants.id
              )
            ) AND vp.role_id IS NULL
          )
        SQL

        lowest_price = "LEAST(spree_prices.amount, COALESCE(#{subquery_min}, spree_prices.amount))"
        joins(master: :prices).where(spree_prices: { currency: Spree::Config.currency }).where("#{lowest_price} >= ?", val)
      end

      # Scope to filter products where highest possible price is <= val
      add_search_scope :price_max do |val|
        return where(nil) if val.blank?
        val = val.to_f

        # Subquery to calculate the maximum volume price for the master variant
        subquery_max = <<~SQL
          (
            SELECT MAX(
              CASE vp.discount_type
                WHEN 'price' THEN vp.amount
                WHEN 'dollar' THEN (spree_prices.amount - vp.amount)
                WHEN 'percent' THEN (spree_prices.amount * (1.0 - vp.amount))
                ELSE spree_prices.amount
              END
            )
            FROM spree_volume_prices vp
            WHERE (
              vp.variant_id = spree_variants.id
              OR vp.volume_price_model_id IN (
                SELECT vvpm.volume_price_model_id
                FROM spree_variants_volume_price_models vvpm
                WHERE vvpm.variant_id = spree_variants.id
              )
            ) AND vp.role_id IS NULL
          )
        SQL

        highest_price = "GREATEST(spree_prices.amount, COALESCE(#{subquery_max}, spree_prices.amount))"
        joins(master: :prices).where(spree_prices: { currency: Spree::Config.currency }).where("#{highest_price} <= ?", val)
      end

      # Override brand_any to flatten arguments and fix the splat bug
      add_search_scope :brand_any do |*opts|
        opts = opts.flatten
        scope = opts.filter_map { |value|
          Spree::Core::ProductFilters.brand_filter[:conds][value]
        }.inject { |scope1, scope2| scope1.or(scope2) }

        with_property("brand").where(scope)
      end
    end
  end
end

Spree::Product.prepend ProductSearchScopesOverride
