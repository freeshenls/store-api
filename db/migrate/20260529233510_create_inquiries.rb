class CreateInquiries < ActiveRecord::Migration[8.1]
  def change
    create_table :inquiries do |t|
      t.string :first_name
      t.string :last_name
      t.string :company_name
      t.string :email
      t.string :phone
      t.string :country
      t.string :color
      t.integer :quantity
      t.date :date_required
      t.text :comments
      t.references :product, null: false, foreign_key: true

      t.timestamps
    end
  end
end
