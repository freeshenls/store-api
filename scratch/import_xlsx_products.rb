# scratch/import_xlsx_products.rb
# Run with: bin/rails runner scratch/import_xlsx_products.rb

require 'roo'
require 'open-uri'
require 'fileutils'

# 1. XLSX Parsing
xlsx_path = Rails.root.join("tmp", "esp_products.xlsx")
unless File.exist?(xlsx_path)
  puts "ERROR: XLSX file not found at: #{xlsx_path}"
  puts "Please run the scraper first: bin/rails runner scratch/scrape_to_xlsx.rb"
  exit 1
end

puts "Parsing XLSX file: #{xlsx_path}..."
xlsx = Roo::Spreadsheet.open(xlsx_path.to_s)
sheet = xlsx.sheet("Products")

# Extract headers
headers = sheet.row(1).map(&:to_s).map(&:strip)
puts "Headers found in Excel: #{headers.inspect}"

imported_count = 0

# Iterate through each row in sheet (from row index 2 to the end)
(2..sheet.last_row).each do |row_idx|
  row_data = sheet.row(row_idx)
  
  # Map row data to headers hash
  row = Hash[headers.zip(row_data)]
  
  cpn = row['cpn']&.to_s&.strip
  title = row['title']&.to_s&.strip
  category = row['category']&.to_s&.strip
  price = row['price']&.to_s&.strip
  old_price = row['old_price']&.to_s&.strip
  min_qty = row['min_qty']&.to_s&.strip
  badge = row['badge']&.to_s&.strip
  section = row['section']&.to_s&.strip || 'New Products'
  
  # Image URLs (1 to 5)
  image_urls = [
    row['image_url_1'],
    row['image_url_2'],
    row['image_url_3'],
    row['image_url_4'],
    row['image_url_5']
  ].compact.map(&:to_s).map(&:strip).select(&:present?)
  
  # Accordions
  product_detail = row['product_detail']&.to_s
  imprint = row['imprint']&.to_s
  production_shipping = row['production_shipping']&.to_s
  safety_compliance = row['safety_compliance']&.to_s

  next if cpn.blank? || title.blank?

  puts "\n--- Importing Excel Row #{row_idx - 1}: #{title} (SKU: #{cpn}) ---"

  # Find or initialize native Product by CPN
  product = Product.find_or_initialize_by(cpn: cpn)
  product.assign_attributes(
    title: title,
    category: category,
    price: price,
    old_price: old_price,
    min_qty: min_qty,
    badge: badge,
    section: section,
    product_detail: product_detail,
    imprint: imprint,
    production_shipping: production_shipping,
    safety_compliance: safety_compliance
  )

  # Generate slug natively if new
  if product.new_record?
    product.slug = title.parameterize
  end

  if product.save
    puts "  Product record saved! ID: #{product.id}, Slug: #{product.slug}"
    
    # Process images if they are provided in Excel
    if image_urls.any?
      # Purge old images if they exist to prevent accumulation of duplicates
      if product.images.attached?
        puts "  Purging #{product.images.size} old attached images..."
        product.images.purge
      end

      image_urls.each_with_index do |image_url, img_idx|
        puts "  Downloading Image #{img_idx + 1}/#{image_urls.size}: #{image_url}"
        begin
          ext = File.extname(URI.parse(image_url).path)
          ext = ".jpg" if ext.blank?
          temp_filename = "xlsx_import_#{row_idx - 1}_#{img_idx + 1}#{ext}"
          temp_filepath = Rails.root.join("tmp", temp_filename)
          
          # Download file stream with safety timeouts
          URI.open(image_url, "User-Agent" => "Mozilla/5.0", read_timeout: 10, open_timeout: 10) do |stream|
            File.open(temp_filepath, "wb") do |f|
              f.write(stream.read)
            end
          end
          
          # Attach via ActiveStorage
          File.open(temp_filepath, "rb") do |file|
            product.images.attach(
              io: file,
              filename: "#{product.slug}_#{img_idx + 1}#{ext}",
              content_type: ext == ".png" ? "image/png" : "image/jpeg"
            )
          end
          puts "    Attached image #{img_idx + 1} successfully!"
          
          File.delete(temp_filepath) if File.exist?(temp_filepath)
        rescue => e
          puts "    ERROR downloading/attaching image #{img_idx + 1}: #{e.message}"
          File.delete(temp_filepath) if File.exist?(temp_filepath) rescue nil
        end
      end
    end
    imported_count += 1
  else
    puts "  ERROR saving product: #{product.errors.full_messages.join(', ')}"
  end
end

puts "\n🎉 Native Excel import completed successfully! Imported #{imported_count} products."
