# scratch/import_manual_dom_data.rb
# Run with: bin/rails runner scratch/import_manual_dom_data.rb

$stdout.sync = true

require 'nokogiri'
require 'open-uri'
require 'fileutils'
require 'securerandom'

# 1. Helper mapping methods
def determine_category(title)
  t = title.to_s.downcase
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

def extract_attributes_html(container)
  return "" unless container
  content_box = container.at_css('.contentContainer') || container
  html_str = content_box.inner_html.to_s.strip
  html_str = html_str.gsub(/\s+/, ' ').strip
  html_str
end

# Sequential download fallback pipeline to resolve 500 errors
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
      URI.open(url, "User-Agent" => "Mozilla/5.0", read_timeout: 6, open_timeout: 6) do |stream|
        File.open(temp_filepath, "wb") do |f|
          f.write(stream.read)
        end
      end
      success = true
      break
    rescue => e
      last_error = e
    end
  end
  
  raise last_error unless success
end

# 2. Scan manual list files
html_files = Dir.glob('db/dom_data/*.html').sort
all_product_containers = []

html_files.each do |f|
  doc = Nokogiri::HTML(File.read(f))
  containers = doc.css('.prodTileWrap .prodPannel')
  containers.each do |container|
    all_product_containers << { file: f, node: container }
  end
end

total_products = all_product_containers.size
puts "=========================================================="
puts "🚀 Starting Comprehensive Image Audit & Import Pipeline"
puts "   Total Products Detected: #{total_products}"
puts "   Files Scanned: #{html_files.map { |f| File.basename(f) }.join(', ')}"
puts "=========================================================="

success_count = 0
skipped_count = 0
failed_count = 0

all_product_containers.each_with_index do |item, idx|
  progress_str = "[#{idx + 1} / #{total_products}]"
  container = item[:node]

  # Parse list details
  title_el = container.css('.prodName span').find { |s| s['id']&.end_with?('_lblTVProdName') }
  title = title_el ? title_el.text.strip : nil
  
  cpn_el = container.css('.prodName.notranslate').first
  cpn = cpn_el ? cpn_el.text.to_s.gsub(/[[:space:]\u00a0]+/, ' ').strip : nil

  if title.blank? || cpn.blank?
    puts "#{progress_str} ⚠️ Skipping: Missing Title or CPN code."
    skipped_count += 1
    next
  end

  # Blacklist compliance check
  if cpn.to_s.include?("556488559")
    puts "#{progress_str} 🚫 Skipping blacklisted product (CPN: #{cpn})."
    skipped_count += 1
    next
  end

  # Check if product already exists
  product_exists = Product.find_by(cpn: cpn)
  existing_image_count = product_exists ? product_exists.images.count : 0
  
  # Optimization: If the product is already fully populated with 2+ images and specs, skip completely!
  if product_exists && existing_image_count >= 2 && product_exists.product_detail.present?
    puts "#{progress_str} 📦 Skipping (Fully Populated): #{title} (SKU: #{cpn}) already has #{existing_image_count} images and specs."
    success_count += 1
    next
  end

  puts "\n#{progress_str} 📦 Auditing & Syncing: #{title} (SKU: #{cpn}) [Current Images: #{existing_image_count}]..."

  begin
    img_el = container.css('.prodImg img').first
    fallback_image_url = img_el ? (img_el['data-original'] || img_el['src']) : nil
    
    # Use pure Ruby to find the input whose ID ends with '_productId' (avoiding Nokogiri CSS translator bugs)
    prod_id_el = container.css('input').find { |i| i['id']&.end_with?('_productId') }
    product_id = prod_id_el ? prod_id_el['value'].to_s.split('|').last : nil
    
    price_el = container.css('.priceLowest span').find { |s| s['id']&.end_with?('_lblPrice') }
    price_str = price_el ? price_el.text.strip.gsub(/\s+/, ' ') : "$1.00 and up"
    
    badge_el = container.css('.prodTags div').first
    badge = badge_el ? badge_el.text.strip : ""
    
    category = determine_category(title)
    
    hd_image_urls = []
    min_qty = "Min: 100 pcs"
    
    product_detail_html = ""
    imprint_html = ""
    production_shipping_html = ""
    safety_compliance_html = ""

    if product_id.present?
      detail_url = "https://atozspecialties.espwebsite.com/ProductDetails/?productID=#{product_id}"
      
      sleep 0.15 # small safety throttle
      
      begin
        detail_html = URI.open(detail_url, "User-Agent" => "Mozilla/5.0", read_timeout: 6, open_timeout: 6).read
        detail_doc = Nokogiri::HTML(detail_html)
        
        # 1. Direct CSS selector check for the Main Product Image
        main_id = nil
        main_img_el = detail_doc.css('img').find { |img| img['id']&.end_with?('_imgProductImage') }
        if main_img_el
          main_url = main_img_el['src'] || main_img_el['data-original']
          if main_url =~ /images\/jpg(?:[otb]|eg)\/\d+\/(\d+)\./
            main_id = $1
          end
        end

        # 2. Extract unique image IDs
        image_ids = detail_html.scan(/images\/jpg(?:[otb]|eg)\/\d+\/(\d+)\./).flatten.uniq
        
        # Unshift main image ID to index 0 to ensure it is always the very first image
        if main_id
          image_ids.delete(main_id)
          image_ids.unshift(main_id)
        end

        # 3. Reconstruct HD JPGO URLs in exact order
        hd_image_urls = image_ids.map do |id|
          folder = (id.to_i / 10000) * 10000
          "https://media-asicdn.azureedge.net/images/jpgo/#{folder}/#{id}.jpg"
        end

        # Min Qty parsing
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
            # JSON parse warning
          end
        end

        # Accordions specs
        detail_containers = detail_doc.css('.attributesContainer')
        if detail_containers.size >= 5
          product_detail_html      = extract_attributes_html(detail_containers[1])
          imprint_html             = extract_attributes_html(detail_containers[2])
          production_shipping_html = extract_attributes_html(detail_containers[3])
          safety_compliance_html   = extract_attributes_html(detail_containers[4])
        end
      rescue => de
        puts "  ⚠️ Details fetch warning: #{de.message}. Using fallback layout values."
      end
    end

    if hd_image_urls.empty? && fallback_image_url.present?
      hd_url = fallback_image_url.gsub('/jpgt/', '/jpgo/').gsub('/jpgb/', '/jpgo/')
      hd_image_urls << hd_url
    end
    hd_image_urls = hd_image_urls.first(5)

    # Upsert product record
    product = Product.find_or_initialize_by(cpn: cpn)
    product.assign_attributes(
      title: title,
      category: category,
      price: price_str,
      min_qty: min_qty,
      badge: badge,
      section: 'New Products',
      product_detail: product_detail_html,
      imprint: imprint_html,
      production_shipping: production_shipping_html,
      safety_compliance: safety_compliance_html
    )

    if product.new_record?
      product.slug = title.parameterize
      if Product.exists?(slug: product.slug)
        product.slug = "#{product.slug}-#{SecureRandom.hex(3)}"
      end
    end

    # Determine if we need to download and attach new images
    should_download_images = true
    if existing_image_count == 1 && hd_image_urls.size <= 1
      should_download_images = false
      puts "     [INFO] Product already has 1 image and details page has <= 1 image. Skipping image download."
    end

    if product.save
      puts "  -> Saved Product ID: #{product.id}, Category: #{category}"
      
      if should_download_images
        # Purge old images to ensure exact ordered rewrite
        product.images.purge if product.images.attached?

        # Download and Attach images in order
        if hd_image_urls.any?
          hd_image_urls.each_with_index do |img_url, img_idx|
            begin
              ext = File.extname(URI.parse(img_url).path)
              ext = ".jpg" if ext.blank?
              temp_filename = "dom_data_audit_#{idx + 1}_#{img_idx + 1}#{ext}"
              temp_filepath = Rails.root.join("tmp", temp_filename)
              
              # Download with sequential fallback pipeline (jpgo -> jpeg -> jpgb -> jpgt)
              download_image_with_fallback(img_url, temp_filepath)
              
              File.open(temp_filepath, "rb") do |file|
                product.images.attach(
                  io: file,
                  filename: "#{product.slug}_#{img_idx + 1}#{ext}",
                  content_type: ext == ".png" ? "image/png" : "image/jpeg"
                )
              end
              
              is_main = img_idx == 0 ? " [MAIN IMAGE]" : ""
              puts "     Attached Image #{img_idx + 1} successfully!#{is_main}"
              File.delete(temp_filepath) if File.exist?(temp_filepath)
            rescue => ie
              puts "     ⚠️ Image download error: #{ie.message}"
              File.delete(temp_filepath) if File.exist?(temp_filepath) rescue nil
            end
          end
        end
      end
      success_count += 1
    else
      puts "  ❌ Save error: #{product.errors.full_messages.join(', ')}"
      failed_count += 1
    end

  rescue => e
    puts "  ❌ Error importing row: #{e.message}"
    failed_count += 1
  end
end

puts "\n=========================================================="
puts "🎉 Image Audit & Import Pipeline Completed!"
puts "   Total Checked/Audited Successfully: #{success_count}"
puts "   Skipped (Blacklisted): #{skipped_count}"
puts "   Failed: #{failed_count}"
puts "   Total Products in DB: #{Product.count}"
puts "=========================================================="
