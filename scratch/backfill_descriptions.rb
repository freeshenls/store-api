# scratch/backfill_descriptions.rb
# Run with: bin/rails runner scratch/backfill_descriptions.rb

require 'nokogiri'
require 'open-uri'
require 'fileutils'

puts "=== Building CPN to Product ID Map ==="
cpn_map = {}

Dir.glob(Rails.root.join("db", "dom_data", "*.html")).each do |html_path|
  puts "Parsing #{File.basename(html_path)}..."
  html = File.read(html_path)
  doc = Nokogiri::HTML(html)
  
  doc.css('.prodTileWrap .prodPannel').each do |container|
    cpn_el = container.css('.prodName.notranslate').first
    next unless cpn_el
    
    # Strip all whitespace and non-breaking spaces
    cpn = cpn_el.text.strip.gsub(/[[:space:]]+/, '')
    
    prod_id_el = container.css('input').find { |i| i['id']&.end_with?('_productId') }
    product_id = prod_id_el ? prod_id_el['value'] : nil
    
    if cpn.present? && product_id.present?
      cpn_map[cpn] = product_id
    end
  end
end

puts "Map built with #{cpn_map.size} unique product mappings."

puts "\n=== Backfilling Product Descriptions ==="
products = Product.all
total = products.count
updated_count = 0
failed_count = 0

products.each_with_index do |product, idx|
  print "\r[#{idx + 1} / #{total}] Processing: #{product.title[0..40]}... "
  
  if product.description.present?
    # Already has a description, skip
    next
  end
  
  # Clean CPN key matching the map
  cpn_key = product.cpn.to_s.gsub(/[[:space:]]+/, '')
  product_id = cpn_map[cpn_key]
  
  if product_id.blank?
    # Try to use numeric part of CPN as fallback, or look up by title
    product_id = product.cpn[/\d+/]
  end
  
  if product_id.present?
    url = "https://atozspecialties.espwebsite.com/ProductDetails/?productID=#{product_id}"
    begin
      html = URI.open(url, "User-Agent" => "Mozilla/5.0", read_timeout: 5, open_timeout: 5).read
      doc = Nokogiri::HTML(html)
      
      desc = doc.at_css('.prodDescrFull')&.text&.strip || doc.at_css('.prodDescr')&.text&.strip
      
      if desc.present?
        product.update!(description: desc)
        updated_count += 1
      else
        failed_count += 1
      end
    rescue => e
      failed_count += 1
    end
  else
    failed_count += 1
  end
end

puts "\n\n🎉 Backfill Complete!"
puts "Updated: #{updated_count} products"
puts "Failed/Skipped: #{failed_count} products"
puts "Total Products in DB: #{Product.count}"
