# frozen_string_literal: true

# This migration comes from solidus_volume_pricing (originally 20111206173307)
class PrefixVolumePricingTableNames < ActiveRecord::Migration[4.2]
  def change
    rename_table :volume_prices, :spree_volume_prices unless Spree::VolumePrice.table_exists?
  end
end
