class AddPriceGridToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :price_grid, :jsonb
  end
end
