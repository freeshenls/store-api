class AddDescriptionToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :description, :text
  end
end
