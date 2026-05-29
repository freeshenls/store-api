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

# 3. HTML Parsing of Search Page
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

# 5. Product Loop
imported_count = 0

product_containers.each_with_index do |container, idx|
  puts "\n--- Importing Product #{idx + 1}/#{product_containers.size} ---"
  
  # Title
  title_el = container.css('.prodName span[id$=_lblTVProdName]').first
  title = title_el ? title_el.text.strip : "Product #{idx + 1}"
  
  # Main Image URL from search results (used as fallback)
  img_el = container.css('.prodImg img').first
  fallback_image_url = img_el ? (img_el['data-original'] || img_el['src']) : nil
  
  # Product ID
  prod_id_el = container.css('input[id$=_productId]').first
  product_id = prod_id_el ? prod_id_el['value'] : nil
  
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
  
  # 5a. Fetch HD Multiple Image URLs from Detail Page & Parse JSON Pricing/Quantities
  hd_image_urls = []
  old_price = nil
  min_qty = "Min: 100 pcs" # Fallback if not found

  if product_id.present?
    detail_url = "https://atozspecialties.espwebsite.com/ProductDetails/?productID=#{product_id}"
    puts "Fetching product details from #{detail_url}..."
    begin
      # Defensive timeouts: read_timeout and open_timeout
      detail_html = URI.open(detail_url, "User-Agent" => "Mozilla/5.0", read_timeout: 5, open_timeout: 5).read
      
      # Extract unique image IDs
      image_ids = detail_html.scan(/images\/jpg(?:[otb]|eg)\/\d+\/(\d+)\./).flatten.uniq
      puts "Found unique image IDs in details: #{image_ids.inspect}"
      
      # Reconstruct HD JPGO URLs
      hd_image_urls = image_ids.map do |id|
        folder = (id.to_i / 10000) * 10000
        "https://media-asicdn.azureedge.net/images/jpgo/#{folder}/#{id}.jpg"
      end

      # Parse original minimum quantity from pricing grid
      if detail_html =~ /var\s+Product\s*=\s*(\{.*?\});/m
        json_str = $1
        begin
          product_data = JSON.parse(json_str)
          prices = product_data["Prices"]
          if prices && prices.any?
            qtys = prices.map { |p| p["Quantity"]["From"].to_i }.uniq.sort
            if qtys.any?
              min_qty = "Min: #{qtys.first} pcs"
            end
            puts "Parsed real minimum quantity: '#{min_qty}'"
          end
        rescue => pe
          puts "WARNING: Failed to parse Product JSON for min qty: #{pe.message}"
        end
      end
    rescue => e
      puts "WARNING: Failed to fetch detail page or extract images: #{e.message}"
    end
  end

  # Fallback to the main search results image if no images were extracted
  if hd_image_urls.empty? && fallback_image_url.present?
    puts "Using search results image as fallback..."
    # Convert fallbacks to high-definition JPGO format if possible
    hd_url = fallback_image_url.gsub('/jpgt/', '/jpgo/').gsub('/jpgb/', '/jpgo/')
    hd_image_urls << hd_url
  end

  # We limit to at most 5 HD images (roles: image, image_2, image_3, image_4, image_5)
  hd_image_urls = hd_image_urls.first(5)
  puts "Target HD URLs to upload (Cap at 5): #{hd_image_urls.inspect}"

  # 5b. Download and upload all HD pictures (Optimized with Reuse)
  uploaded_pictures = []

  hd_image_urls.each_with_index do |image_url, img_idx|
    picture_name = "#{title.parameterize}_#{img_idx + 1}"
    existing_picture = Alchemy::Picture.find_by(name: picture_name)
    
    if existing_picture
      puts "Image #{img_idx + 1} already uploaded! Reusing existing Picture ID: #{existing_picture.id}"
      uploaded_pictures << existing_picture
      next
    end

    puts "Processing Image #{img_idx + 1}/#{hd_image_urls.size}: #{image_url}"
    begin
      # Generate temp file path
      ext = File.extname(URI.parse(image_url).path)
      ext = ".jpg" if ext.blank?
      temp_filename = "esp_import_#{idx + 1}_#{img_idx + 1}#{ext}"
      temp_filepath = Rails.root.join("tmp", temp_filename)
      
      # Download file stream to temp file - Defensive timeouts to prevent hanging
      URI.open(image_url, "User-Agent" => "Mozilla/5.0", read_timeout: 5, open_timeout: 5) do |stream|
        File.open(temp_filepath, "wb") do |f|
          f.write(stream.read)
        end
      end
      
      # Create Alchemy::Picture
      puts "Uploading HD image to Cloudflare R2 via ActiveStorage..."
      picture = Alchemy::Picture.new(name: picture_name)
      File.open(temp_filepath, "rb") do |file|
        picture.image_file.attach(
          io: file,
          filename: temp_filename,
          content_type: ext == ".png" ? "image/png" : "image/jpeg"
        )
        
        # Save picture INSIDE the block while the file stream is open!
        if picture.save
          puts "Image #{img_idx + 1} uploaded successfully! Picture ID: #{picture.id}"
          uploaded_pictures << picture
        else
          puts "ERROR saving picture #{img_idx + 1}: #{picture.errors.full_messages.join(', ')}"
        end
      end
      
      # Clean up local temp file immediately to keep local storage pristine
      File.delete(temp_filepath) if File.exist?(temp_filepath)
    rescue => e
      puts "ERROR downloading/uploading image #{img_idx + 1}: #{e.message}"
      # Clean up if it failed after file creation
      File.delete(temp_filepath) if File.exist?(temp_filepath) rescue nil
    end
  end

  # 5c. Create Element
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
    
    # Map uploaded pictures to ingredients: image, image_2, image_3, image_4, image_5
    uploaded_pictures.each_with_index do |picture, pic_idx|
      role_name = pic_idx == 0 ? 'image' : "image_#{pic_idx + 1}"
      set_ingredient(new_el, role_name, nil, related_object_id: picture.id, related_object_type: 'Alchemy::Picture')
      puts "Associated Picture ID #{picture.id} with ingredient role: #{role_name}"
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
    puts "Successfully imported #{imported_count} products with multiple HD images!"
  rescue => e
    puts "ERROR publishing page: #{e.message}"
  end
else
  puts "No products were imported."
end
