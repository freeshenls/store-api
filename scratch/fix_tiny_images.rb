# scratch/fix_tiny_images.rb
# Run with: bin/rails runner scratch/fix_tiny_images.rb

require 'nokogiri'
require 'open-uri'
require 'fileutils'

puts "=== Tiny/Broken Images Identification and Re-download Session ==="

# Find unique products with 722-byte attachments
tiny_attachments = ActiveStorage::Attachment.where(record_type: 'Product', name: 'images').joins(:blob).where('active_storage_blobs.byte_size = 722')
product_ids = tiny_attachments.pluck(:record_id).uniq

# Also explicitly add CPN-556552629 (Universal Beverage Bottle Spray Wand) to ensure its order is perfectly fixed!
spray_wand = Product.find_by(slug: 'universal-beverage-bottle-pull-telescopic-spray-wand')
product_ids << spray_wand.id if spray_wand && !product_ids.include?(spray_wand.id)

target_products = Product.where(id: product_ids)
puts "Found #{target_products.count} products to repair."

if target_products.empty?
  puts "🎉 No products with broken tiny images found!"
  exit 0
end

def determine_category(title)
  t = title.to_s.downcase
  if t.include?("shirt") || t.include?("apparel") || t.include?("polo")
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
  elsif t.include?("flashlight") || t.include?("multitool") || t.include?("tool") || t.include?("pliers")
    "Tools & Flashlights"
  elsif t.include?("planter") || t.include?("flower")
    "Home & Garden"
  elsif t.include?("case") || t.include?("sd tf")
    "Electronics"
  elsif t.include?("box") || t.include?("candy") || t.include?("favor")
    "Novelties"
  else
    "Promotional Items"
  end
end

def extract_attributes_html(container)
  return "" unless container
  content_box = container.at_css('.contentContainer') || container
  html_str = content_box.inner_html.to_s.strip
  html_str = html_str.gsub(/\s+/, ' ').strip
  html_str
end

def download_image_with_fallback(img_url, temp_filepath)
  urls_to_try = [img_url]
  if img_url.include?("/images/jpgo/")
    urls_to_try << img_url.gsub("/images/jpgo/", "/images/jpeg/")
    urls_to_try << img_url.gsub("/images/jpgo/", "/images/jpgb/")
    urls_to_try << img_url.gsub("/images/jpgo/", "/images/jpgt/")
  end
  urls_to_try.uniq!
  
  success = false
  last_error = nil
  
  urls_to_try.each do |url|
    begin
      URI.open(url, "User-Agent" => "Mozilla/5.0", read_timeout: 10, open_timeout: 10) do |stream|
        File.open(temp_filepath, "wb") do |f|
          f.write(stream.read)
        end
      end
      
      # Double check if downloaded file size is tiny (less than 2KB). 
      # If it is, the server returned a placeholder WebP spacer, so we reject it and try the fallback!
      if File.size(temp_filepath) < 2048
        raise "Downloaded file is a tiny placeholder (#{File.size(temp_filepath)} bytes)."
      end
      
      success = true
      break
    rescue => e
      last_error = e
    end
  end
  raise last_error unless success
end

# 1. Scan HTML files to find matching product details
html_files = Dir.glob('db/dom_data/*.html').sort
product_nodes = {}

html_files.each do |f|
  doc = Nokogiri::HTML(File.read(f))
  doc.css('.prodTileWrap .prodPannel').each do |container|
    cpn_el = container.css('.prodName.notranslate').first
    cpn = cpn_el ? cpn_el.text.to_s.gsub(/[[:space:]\u00a0]+/, ' ').strip : nil
    if cpn.present? && target_products.pluck(:cpn).include?(cpn)
      product_nodes[cpn] = container
    end
  end
end

success_count = 0

target_products.each_with_index do |product, idx|
  cpn = product.cpn
  container = product_nodes[cpn]
  
  unless container
    puts "❌ Could not find container in HTML files for CPN: #{cpn}"
    next
  end

  puts "\n========================================="
  puts "🔄 Repairing: #{product.title} (SKU: #{cpn}) [#{idx+1} / #{target_products.count}]"
  puts "========================================="

  # Parse details
  prod_id_el = container.css('input').find { |i| i['id']&.end_with?('_productId') }
  product_id = prod_id_el ? prod_id_el['value'].to_s.split('|').last : nil
  
  img_el = container.css('.prodImg img').first
  fallback_image_url = img_el ? (img_el['data-original'] || img_el['src']) : nil
  
  price_el = container.css('.priceLowest span').find { |s| s['id']&.end_with?('_lblPrice') }
  price_str = price_el ? price_el.text.strip.gsub(/\s+/, ' ') : "$1.00 and up"
  
  badge_el = container.css('.prodTags div').first
  badge = badge_el ? badge_el.text.strip : ""
  
  category = determine_category(product.title)

  if product_id.blank?
    puts "❌ Product ID not found for #{cpn}"
    next
  end

  detail_url = "https://atozspecialties.espwebsite.com/ProductDetails/?productID=#{product_id}"
  
  # Fetch details page with retries and 15-second timeouts
  detail_html = nil
  retries = 3
  
  retries.times do |attempt|
    begin
      detail_html = URI.open(detail_url, "User-Agent" => "Mozilla/5.0", read_timeout: 15, open_timeout: 15).read
      break # success!
    rescue => e
      puts "  ⚠️ Attempt #{attempt + 1} failed: #{e.message}"
      sleep 2 if attempt < retries - 1
    end
  end

  if detail_html.blank?
    puts "❌ Skipping spec and image recovery due to connection failure."
    next
  end

  # Parse page content
  detail_doc = Nokogiri::HTML(detail_html)
  
  # Image Extraction
  main_id = nil
  main_img_el = detail_doc.css('img').find { |img| img['id']&.end_with?('_imgProductImage') }
  if main_img_el
    main_url = main_img_el['src'] || main_img_el['data-original']
    if main_url =~ /images\/jpg(?:[otb]|eg)\/\d+\/(\d+)\./
      main_id = $1
    end
  end

  image_ids = detail_html.scan(/images\/jpg(?:[otb]|eg)\/\d+\/(\d+)\./).flatten.uniq
  if main_id
    image_ids.delete(main_id)
    image_ids.unshift(main_id)
  end

  hd_image_urls = image_ids.map do |id|
    folder = (id.to_i / 10000) * 10000
    "https://media-asicdn.azureedge.net/images/jpgo/#{folder}/#{id}.jpg"
  end

  if hd_image_urls.empty? && fallback_image_url.present?
    hd_url = fallback_image_url.gsub('/jpgt/', '/jpgo/').gsub('/jpgb/', '/jpgo/')
    hd_image_urls << hd_url
  end
  hd_image_urls = hd_image_urls.first(5)

  # Min Qty
  min_qty = "Min: 100 pcs"
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
      end
    rescue => pe
      # json parse warning
    end
  end

  # Specs accordions
  product_detail_html      = ""
  imprint_html             = ""
  production_shipping_html = ""
  safety_compliance_html   = ""

  detail_containers = detail_doc.css('.attributesContainer')
  if detail_containers.size >= 5
    product_detail_html      = extract_attributes_html(detail_containers[1])
    imprint_html             = extract_attributes_html(detail_containers[2])
    production_shipping_html = extract_attributes_html(detail_containers[3])
    safety_compliance_html   = extract_attributes_html(detail_containers[4])
  end

  # Update product details
  product.assign_attributes(
    category: category,
    price: price_str,
    min_qty: min_qty,
    badge: badge
  )
  
  if product_detail_html.present?
    product.assign_attributes(
      product_detail: product_detail_html,
      imprint: imprint_html,
      production_shipping: production_shipping_html,
      safety_compliance: safety_compliance_html
    )
  end

  if product.save
    puts "✅ Product attributes saved."
    
    # Purge old images and attach fresh new HD ones in order
    product.images.purge if product.images.attached?
    attached_count = 0

    if hd_image_urls.any?
      hd_image_urls.each_with_index do |img_url, img_idx|
        begin
          ext = File.extname(URI.parse(img_url).path)
          ext = ".jpg" if ext.blank?
          temp_filename = "dom_data_repair_#{cpn}_#{img_idx + 1}#{ext}"
          temp_filepath = Rails.root.join("tmp", temp_filename)
          
          download_image_with_fallback(img_url, temp_filepath)
          
          File.open(temp_filepath, "rb") do |file|
            product.images.attach(
              io: file,
              filename: "#{product.slug}_#{img_idx + 1}#{ext}",
              content_type: ext == ".png" ? "image/png" : "image/jpeg"
            )
          end
          is_main = img_idx == 0 ? " [MAIN IMAGE]" : ""
          puts "  -> Attached Image #{img_idx + 1} successfully!#{is_main} (#{File.size(temp_filepath)} bytes)"
          attached_count += 1
          File.delete(temp_filepath) if File.exist?(temp_filepath)
        rescue => ie
          puts "  ⚠️ Image download error for #{img_url}: #{ie.message}"
          File.delete(temp_filepath) if File.exist?(temp_filepath) rescue nil
        end
      end
    end
    
    if attached_count > 0
      success_count += 1
    else
      puts "❌ Failed to attach any valid images for #{cpn}."
    end
  else
    puts "❌ Save error: #{product.errors.full_messages.join(', ')}"
  end
end

puts "\n=== Recovery Complete ==="
puts "Successfully repaired specifications and image packs for: #{success_count} / #{target_products.count} products."
puts "Remaining products with 722-byte attachments: #{ActiveStorage::Attachment.where(record_type: 'Product', name: 'images').joins(:blob).where('active_storage_blobs.byte_size = 722').pluck(:record_id).uniq.count}"
