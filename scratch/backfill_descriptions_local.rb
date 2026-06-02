# scratch/backfill_descriptions_local.rb
# Run with: bin/rails runner scratch/backfill_descriptions_local.rb

require 'nokogiri'

puts "=== Loading local descriptions from db/dom_data/ ==="
cpn_desc_map = {}

Dir.glob(Rails.root.join("db", "dom_data", "*.html")).each do |html_path|
  puts "Parsing #{File.basename(html_path)}..."
  html = File.read(html_path)
  doc = Nokogiri::HTML(html)
  
  doc.css('.prodTileWrap .prodPannel').each do |container|
    cpn_el = container.css('.prodName.notranslate').first
    next unless cpn_el
    
    # Strip all whitespace and non-breaking spaces to make robust keys
    cpn = cpn_el.text.strip.gsub(/[[:space:]]+/, '')
    
    desc_el = container.css('.prodDescr').first
    desc = desc_el ? desc_el.text.strip : nil
    
    if cpn.present? && desc.present?
      cpn_desc_map[cpn] = desc
    end
  end
end

puts "Loaded #{cpn_desc_map.size} unique CPN-to-description mappings."

puts "\n=== Backfilling Product Descriptions Natively ==="
products = Product.all
total = products.count
updated_count = 0
skipped_count = 0
failed_count = 0

Product.transaction do
  products.each do |product|
    # Clean CPN key matching the map
    cpn_key = product.cpn.to_s.gsub(/[[:space:]]+/, '')
    desc = cpn_desc_map[cpn_key]
    
    if desc.present?
      if product.description != desc
        product.update!(description: desc)
        updated_count += 1
      else
        skipped_count += 1
      end
    else
      failed_count += 1
    end
  end
end

puts "\n🎉 Backfill Complete!"
puts "Updated: #{updated_count} products"
puts "Already Correct / Skipped: #{skipped_count} products"
puts "Not Found in local map: #{failed_count} products"
puts "Total Products in DB: #{Product.count}"
