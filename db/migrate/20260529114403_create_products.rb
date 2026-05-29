class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :title
      t.string :slug
      t.string :cpn
      t.string :price
      t.string :old_price
      t.string :min_qty
      t.string :badge
      t.string :category
      t.string :section, default: "New Products"
      t.text :product_detail
      t.text :imprint
      t.text :production_shipping
      t.text :safety_compliance

      t.timestamps
    end

    add_index :products, :slug, unique: true

  end
end
