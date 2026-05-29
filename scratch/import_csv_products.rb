# scratch/import_csv_products.rb
# Run with: bin/rails runner scratch/import_csv_products.rb

require 'csv'
require 'open-uri'
require 'fileutils'

# 1. Target Page Identification
page = Alchemy::Page.find_by(page_layout: 'products') || Alchemy::Page.find_by(id: 2)
unless page
  puts "ERROR: Products page not found!"
  exit 1
end

puts "Target Page Found: ID=#{page.id}, Name='#{page.name}'"
draft_version = page.draft_version || page.versions.create!
puts "Draft Version: ID=#{draft_version.id}"

# 2. Database Cleansing (Clear existing elements on draft version to start fresh)
existing_elements = draft_version.elements.where(name: 'product_card')
puts "Found #{existing_elements.count} existing product cards. Deleting them..."
existing_elements.destroy_all
puts "Existing product cards cleared."

# 3. CSV Parsing
csv_path = Rails.root.join("tmp", "esp_products.csv")
unless File.exist?(csv_path)
  puts "ERROR: CSV file not found at: #{csv_path}"
  puts "Please run the scraper first: bin/rails runner scratch/scrape_to_csv.rb"
  exit 1
end

puts "Parsing CSV file: #{csv_path}..."

# Helper method to set Alchemy element ingredients safely
def set_ingredient(element, role, value, extra = {})
  ing = element.ingredients.find_by(role: role)
  if ing
    ing.update!({ value: value }.merge(extra))
  else
    type = case role
           when /image/ then 'Alchemy::Ingredients::Picture'
           when 'section' then 'Alchemy::Ingredients::Select'
           when 'product_detail', 'imprint', 'production_shipping', 'safety_compliance' then 'Alchemy::Ingredients::Richtext'
           else 'Alchemy::Ingredients::Text'
           end
    element.ingredients.create!({
      role: role,
      type: type,
      value: value
    }.merge(extra))
  end
end

imported_count = 0
idx = 0

# Excel-safe BOM and UTF-8 encoding support
CSV.foreach(csv_path, headers: true, encoding: "bom|utf-8") do |row|
  idx += 1
  cpn = row['cpn']
  title = row['title']
  category = row['category']
  price = row['price']
  old_price = row['old_price']
  min_qty = row['min_qty']
  badge = row['badge']
  section = row['section'] || 'New Products'
  
  # Image URLs (1 to 5)
  image_urls = [
    row['image_url_1'],
    row['image_url_2'],
    row['image_url_3'],
    row['image_url_4'],
    row['image_url_5']
  ].compact.select(&:present?)
  
  # Accordions
  product_detail = row['product_detail']
  imprint = row['imprint']
  production_shipping = row['production_shipping']
  safety_compliance = row['safety_compliance']

  puts "\n--- Importing CSV Row #{idx}: #{title} (SKU: #{cpn}) ---"

  # 4. Download and upload images (Optimized with Reuse)
  uploaded_pictures = []

  image_urls.each_with_index do |image_url, img_idx|
    picture_name = "#{title.parameterize}_#{img_idx + 1}"
    existing_picture = Alchemy::Picture.find_by(name: picture_name)
    
    if existing_picture
      puts "  Image #{img_idx + 1} already uploaded! Reusing Picture ID: #{existing_picture.id}"
      uploaded_pictures << existing_picture
      next
    end

    puts "  Processing Image #{img_idx + 1}/#{image_urls.size}: #{image_url}"
    begin
      ext = File.extname(URI.parse(image_url).path)
      ext = ".jpg" if ext.blank?
      temp_filename = "csv_import_#{idx}_#{img_idx + 1}#{ext}"
      temp_filepath = Rails.root.join("tmp", temp_filename)
      
      # Download file stream with safety timeouts
      URI.open(image_url, "User-Agent" => "Mozilla/5.0", read_timeout: 5, open_timeout: 5) do |stream|
        File.open(temp_filepath, "wb") do |f|
          f.write(stream.read)
        end
      end
      
      # Create Alchemy::Picture (uploads to R2 via ActiveStorage)
      picture = Alchemy::Picture.new(name: picture_name)
      File.open(temp_filepath, "rb") do |file|
        picture.image_file.attach(
          io: file,
          filename: temp_filename,
          content_type: ext == ".png" ? "image/png" : "image/jpeg"
        )
        
        if picture.save
          puts "  Image #{img_idx + 1} uploaded successfully! Picture ID: #{picture.id}"
          uploaded_pictures << picture
        else
          puts "  ERROR saving picture #{img_idx + 1}: #{picture.errors.full_messages.join(', ')}"
        end
      end
      
      File.delete(temp_filepath) if File.exist?(temp_filepath)
    rescue => e
      puts "  ERROR downloading/uploading image #{img_idx + 1}: #{e.message}"
      File.delete(temp_filepath) if File.exist?(temp_filepath) rescue nil
    end
  end

  # 5. Create Element on Page Draft
  begin
    new_el = Alchemy::Element.create!(
      name: 'product_card',
      page_version: draft_version,
      position: idx,
      public_on: Time.current
    )
    
    # Set text ingredients
    set_ingredient(new_el, 'title', title)
    set_ingredient(new_el, 'slug', title.parameterize)
    set_ingredient(new_el, 'price', price)
    set_ingredient(new_el, 'old_price', old_price)
    set_ingredient(new_el, 'min_qty', min_qty)
    set_ingredient(new_el, 'badge', badge)
    set_ingredient(new_el, 'category', category)
    set_ingredient(new_el, 'section', section)
    
    # Set rich text accordions (HTML format)
    set_ingredient(new_el, 'product_detail', product_detail) if product_detail.present?
    set_ingredient(new_el, 'imprint', imprint) if imprint.present?
    set_ingredient(new_el, 'production_shipping', production_shipping) if production_shipping.present?
    set_ingredient(new_el, 'safety_compliance', safety_compliance) if safety_compliance.present?
    
    # Map pictures
    uploaded_pictures.each_with_index do |picture, pic_idx|
      role_name = pic_idx == 0 ? 'image' : "image_#{pic_idx + 1}"
      set_ingredient(new_el, role_name, nil, related_object_id: picture.id, related_object_type: 'Alchemy::Picture')
    end
    
    puts "  Successfully imported product #{idx} into draft!"
    imported_count += 1
  rescue => e
    puts "  ERROR creating element for product: #{e.message}"
    puts e.backtrace.first(5).join("\n")
  end
end

# 6. Page Publication
puts "\n--- Finalizing and Publishing Page ---"
if imported_count > 0
  begin
    puts "Publishing page ID #{page.id}..."
    Alchemy::PublishPageJob.perform_now(page.id, public_on: Time.current)
    puts "Products page published successfully!"
    puts "🎉 Successfully imported #{imported_count} products from CSV catalog!"
  rescue => e
    puts "ERROR publishing page: #{e.message}"
  end
else
  puts "No products were imported."
end
