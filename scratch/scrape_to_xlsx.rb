# scratch/scrape_to_xlsx.rb
# Run with: bin/rails runner scratch/scrape_to_xlsx.rb

require 'nokogiri'
require 'open-uri'
require 'fileutils'
require 'axlsx'
require 'json'

# 1. HTML Parsing of Search Page
content_path = '/Users/promote/.gemini/antigravity/brain/2e81f3f9-81db-4b3f-885a-bacbb46aef11/.system_generated/steps/4188/content.md'
unless File.exist?(content_path)
  puts "ERROR: Content file not found at: #{content_path}"
  exit 1
end

html = File.read(content_path)
doc = Nokogiri::HTML(html)
product_containers = doc.css('.prodTileWrap .prodPannel')

# Export all products found in the source document
target_containers = product_containers
puts "Found #{product_containers.size} products. Exporting all #{target_containers.size} products."

# 2. Helper Mapping Methods
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

def extract_attributes_html(container)
  return "" unless container
  
  # Try to extract the inner content container which holds the actual rich specifications and tables
  content_box = container.at_css('.contentContainer') || container
  
  # Get raw inner HTML
  html_str = content_box.inner_html.to_s.strip
  
  # Clean up extra spacing while preserving HTML tags (tables, rows, lists, cells)
  html_str = html_str.gsub(/\s+/, ' ').strip
  html_str
end

# 3. XLSX Preparation
xlsx_path = Rails.root.join("tmp", "esp_products.xlsx")
FileUtils.mkdir_p(xlsx_path.dirname)

p = Axlsx::Package.new
wb = p.workbook

headers = [
  'cpn', 'title', 'category', 'price', 'old_price', 'min_qty', 'badge', 'section',
  'image_url_1', 'image_url_2', 'image_url_3', 'image_url_4', 'image_url_5',
  'product_detail', 'imprint', 'production_shipping', 'safety_compliance'
]

wb.add_worksheet(name: "Products") do |sheet|
  # Add headers row
  sheet.add_row headers
  
  target_containers.each_with_index do |container, idx|
    puts "\n--- Scraping Product #{idx + 1}/#{target_containers.size} ---"
    
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
    
    # Fetch HD Multiple Image URLs from Detail Page & Parse JSON Pricing/Quantities
    hd_image_urls = []
    old_price = nil
    min_qty = "Min: 100 pcs" # Fallback if not found
    
    # Accordion specs
    product_detail_html = ""
    imprint_html = ""
    production_shipping_html = ""
    safety_compliance_html = ""

    if product_id.present?
      detail_url = "https://atozspecialties.espwebsite.com/ProductDetails/?productID=#{product_id}"
      puts "Fetching product details from #{detail_url}..."
      begin
        detail_html = URI.open(detail_url, "User-Agent" => "Mozilla/5.0", read_timeout: 5, open_timeout: 5).read
        detail_doc = Nokogiri::HTML(detail_html)
        
        # Extract unique image IDs
        image_ids = detail_html.scan(/images\/jpg(?:[otb]|eg)\/\d+\/(\d+)\./).flatten.uniq
        
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
            end
          rescue => pe
            puts "WARNING: Failed to parse Product JSON for min qty: #{pe.message}"
          end
        end
        
        # Parse specification accordions
        detail_containers = detail_doc.css('.attributesContainer')
        if detail_containers.size >= 5
          product_detail_html      = extract_attributes_html(detail_containers[1])
          imprint_html             = extract_attributes_html(detail_containers[2])
          production_shipping_html = extract_attributes_html(detail_containers[3])
          safety_compliance_html   = extract_attributes_html(detail_containers[4])
        end
        
      rescue => e
        puts "WARNING: Failed to fetch detail page or extract specs: #{e.message}"
      end
    end

    # Fallback to the main search results image if no images were extracted
    if hd_image_urls.empty? && fallback_image_url.present?
      hd_url = fallback_image_url.gsub('/jpgt/', '/jpgo/').gsub('/jpgb/', '/jpgo/')
      hd_image_urls << hd_url
    end

    # Limit to at most 5 images
    hd_image_urls = hd_image_urls.first(5)
    
    # Add row to Excel sheet
    sheet.add_row [
      cpn,
      title,
      category,
      price_str,
      old_price,
      min_qty,
      badge,
      'New Products',
      hd_image_urls[0],
      hd_image_urls[1],
      hd_image_urls[2],
      hd_image_urls[3],
      hd_image_urls[4],
      product_detail_html,
      imprint_html,
      production_shipping_html,
      safety_compliance_html
    ]
    puts "Successfully scraped and prepared: #{title} (SKU: #{cpn})"
  end
end

p.serialize(xlsx_path)

puts "\n🎉 Scraping completed successfully! Output saved to Excel: #{xlsx_path}"
puts "Please open, review, and edit the XLSX file in Microsoft Excel or Google Sheets."
puts "Once reviewed, run: bin/rails runner scratch/import_xlsx_products.rb"
