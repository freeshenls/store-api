# frozen_string_literal: true

# This migration comes from solidus_volume_pricing (originally 20150513200904)
class AddRoleToVolumePrice < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_volume_prices, :role_id, :integer
  end
end
