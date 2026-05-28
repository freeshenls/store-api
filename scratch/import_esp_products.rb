# scratch/import_esp_products.rb
# Run with: bin/rails runner scratch/import_esp_products.rb

require 'nokogiri'
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

# 3. HTML Parsing
content_path = '/Users/promote/.gemini/antigravity/brain/2e81f3f9-81db-4b3f-885a-bacbb46aef11/.system_generated/steps/4188/content.md'
unless File.exist?(content_path)
  puts "ERROR: Content file not found at: #{content_path}"
  exit 1
end

html = File.read(content_path)
doc = Nokogiri::HTML(html)
product_containers = doc.css('.prodTileWrap .prodPannel')
puts "Found #{product_containers.size} products to import from HTML."

# 4. Helper Mapping Methods
def determine_category(title)
  t = title.downcase
  if t.include?("shirt") || t.include?("crop top") || t.include?("sports bra") || t.include?("apparel") || t.include?("polo")
    "Apparel"
  elsif t.include?("wristband")
    "Wristbands"
  elsif t.include?("brooch") || t.include?("pin")
    "Badges & Pins"
  elsif t.include?("brush") || t.include?("grooming")
    "Personal Care"
  elsif t.include?("keychain")
    "Keychains"
  elsif t.include?("spinner") || t.include?("stress reliever") || t.include?("stress ball") || t.include?("fidget")
    "Fidgets"
  elsif t.include?("pen") || t.include?("ballpoint")
    "Pens & Writing"
  elsif t.include?("flashlight") || t.include?("multitool") || t.include?("tool")
    "Tools & Flashlights"
  elsif t.include?("planter") || t.include?("flower")
    "Home & Garden"
  elsif t.include?("case") || t.include?("sd tf")
    "Electronics"
  elsif t.include?("box") || t.include?("candy") || t.include?("clapper board") || t.include?("favor")
    "Novelties"
  else
    "Promotional Items"
  end
end

def set_ingredient(element, role, value, extra = {})
  ing = element.ingredients.find_by(role: role)
  if ing
    ing.update!({ value: value }.merge(extra))
  else
    type = case role
           when 'image' then 'Alchemy::Ingredients::Picture'
           when 'section' then 'Alchemy::Ingredients::Select'
           else 'Alchemy::Ingredients::Text'
           end
    element.ingredients.create!({
      role: role,
      type: type,
      value: value
    }.merge(extra))
  end
end

# 5. Product Loop
imported_count = 0

product_containers.each_with_index do |container, idx|
  puts "\n--- Importing Product #{idx + 1}/#{product_containers.size} ---"
  
  # Title
  title_el = container.css('.prodName span[id$=_lblTVProdName]').first
  title = title_el ? title_el.text.strip : "Product #{idx + 1}"
  
  # Image URL
  img_el = container.css('.prodImg img').first
  image_url = img_el ? (img_el['data-original'] || img_el['src']) : nil
  
  # CPN (SKU)
  cpn_el = container.css('.prodName.notranslate').first
  cpn = cpn_el ? cpn_el.text.strip.gsub(/\s+/, ' ') : "AP#{rand(10000..99999)}"
  
  # Price
  price_el = container.css('.priceLowest span[id$=_lblPrice]').first
  price_str = price_el ? price_el.text.strip.gsub(/\s+/, ' ') : "$1.00 and up"
  
  # Badge
  badge_el = container.css('.prodTags div').first
  badge = badge_el ? badge_el.text.strip : ""
  
  # Category
  category = determine_category(title)
  
  # Price parsing & dynamic math for comparative prices and min qty
  price_float = price_str[/\d+(\.\d+)?/].to_f
  if price_float > 0
    if price_float < 1.0
      old_price = sprintf("$%.2f", price_float * 1.4)
      min_qty = "Min: 1000 pcs"
    elsif price_float < 5.0
      old_price = sprintf("$%.2f", price_float * 1.3)
      min_qty = "Min: 250 pcs"
    elsif price_float < 10.0
      old_price = sprintf("$%.2f", price_float * 1.25)
      min_qty = "Min: 100 pcs"
    else
      old_price = sprintf("$%.2f", price_float * 1.2)
      min_qty = "Min: 50 pcs"
    end
  else
    old_price = nil
    min_qty = "Min: 100 pcs"
  end

  puts "Title: '#{title}'"
  puts "Category: '#{category}' | SKU: '#{cpn}' | Price: '#{price_str}' (Old: '#{old_price}') | Min Qty: '#{min_qty}' | Badge: '#{badge}'"

  # Image download and R2 upload
  picture = nil
  if image_url.present?
    puts "Downloading image from #{image_url}..."
    begin
      # Generate temp file path
      ext = File.extname(URI.parse(image_url).path)
      ext = ".jpg" if ext.blank?
      temp_filename = "esp_import_#{idx + 1}#{ext}"
      temp_filepath = Rails.root.join("tmp", temp_filename)
      
      # Download file stream to temp file
      URI.open(image_url, "User-Agent" => "Mozilla/5.0") do |stream|
        File.open(temp_filepath, "wb") do |f|
          f.write(stream.read)
        end
      end
      
      # Create Alchemy::Picture
      puts "Uploading image to Cloudflare R2 via ActiveStorage..."
      picture = Alchemy::Picture.new(name: title.parameterize)
      File.open(temp_filepath, "rb") do |file|
        picture.image_file.attach(
          io: file,
          filename: temp_filename,
          content_type: ext == ".png" ? "image/png" : "image/jpeg"
        )
        
        # Save picture INSIDE the block while the file stream is open!
        if picture.save
          puts "Image uploaded successfully! Picture ID: #{picture.id}"
        else
          puts "ERROR saving picture: #{picture.errors.full_messages.join(', ')}"
          picture = nil
        end
      end
      
      # Clean up local temp file immediately to keep local storage pristine
      File.delete(temp_filepath) if File.exist?(temp_filepath)
      puts "Local temporary file cleaned up."
    rescue => e
      puts "ERROR downloading/uploading image: #{e.message}"
      # Clean up if it failed after file creation
      File.delete(temp_filepath) if File.exist?(temp_filepath) rescue nil
    end
  else
    puts "No image URL found for this product."
  end

  # Create Element
  begin
    puts "Creating product_card element on page draft..."
    new_el = Alchemy::Element.create!(
      name: 'product_card',
      page_version: draft_version,
      position: idx + 1,
      public_on: Time.current
    )
    
    # Set ingredients
    set_ingredient(new_el, 'title', title)
    set_ingredient(new_el, 'slug', title.parameterize)
    set_ingredient(new_el, 'price', price_str)
    set_ingredient(new_el, 'old_price', old_price)
    set_ingredient(new_el, 'min_qty', min_qty)
    set_ingredient(new_el, 'badge', badge)
    set_ingredient(new_el, 'category', category)
    set_ingredient(new_el, 'section', 'New Products')
    
    if picture
      set_ingredient(new_el, 'image', nil, related_object_id: picture.id, related_object_type: 'Alchemy::Picture')
    end
    
    puts "Product imported successfully!"
    imported_count += 1
  rescue => e
    puts "ERROR creating element for product: #{e.message}"
    puts e.backtrace.join("\n")
  end
end

# 6. Page Publication
puts "\n--- Finalizing and Publishing Page ---"
if imported_count > 0
  begin
    puts "Publishing page ID #{page.id}..."
    Alchemy::PublishPageJob.perform_now(page.id, public_on: Time.current)
    puts "Products page published successfully!"
    puts "Successfully imported #{imported_count} products!"
  rescue => e
    puts "ERROR publishing page: #{e.message}"
  end
else
  puts "No products were imported."
end
