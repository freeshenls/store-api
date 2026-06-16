class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      # 1. 基础核心文本
      t.string :title
      t.string :sku
      t.string :slug
      t.string :guid            # 灵魂去重主键，防线死死守住
      t.string :category
      
      # 2. 核心价格与起订量
      t.string :price
      t.string :min_qty

      # 3. 大文本商品简述
      t.text :description

      # 4. 图片核心资产
      t.string :main_image_url
      
      # 5. SQLite 原生 JSON 矩阵
      t.json :image_urls
      t.json :price_grid
      t.json :setup_prices

      # 6. 系统自动时间戳 (created_at 和 updated_at)
      t.timestamps

      # 7. 1秒灌入9120条数据的绝杀防线
      t.index ["guid"], name: "index_products_on_guid", unique: true
    end
  end
end
