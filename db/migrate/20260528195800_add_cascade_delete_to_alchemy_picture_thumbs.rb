class AddCascadeDeleteToAlchemyPictureThumbs < ActiveRecord::Migration[8.1]
  def change
    # Remove the existing foreign key constraint
    remove_foreign_key :alchemy_picture_thumbs, :alchemy_pictures

    # Add the foreign key constraint with cascade delete
    add_foreign_key :alchemy_picture_thumbs, :alchemy_pictures, column: :picture_id, on_delete: :cascade
  end
end
