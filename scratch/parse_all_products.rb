# scratch/parse_all_products.rb
require 'nokogiri'

content_path = '/Users/promote/.gemini/antigravity/brain/2e81f3f9-81db-4b3f-885a-bacbb46aef11/.system_generated/steps/4188/content.md'
html = File.read(content_path)
doc = Nokogiri::HTML(html)

product_containers = doc.css('.prodTileWrap .prodPannel')
puts "Found #{product_containers.size} products."

product_containers.each_with_index do |container, idx|
  title_el = container.css('.prodName span[id$=_lblTVProdName]').first
  title = title_el ? title_el.text.strip : "Unknown"
  
  price_el = container.css('.priceLowest span[id$=_lblPrice]').first
  price = price_el ? price_el.text.strip : "N/A"
  
  badge_el = container.css('.prodTags div').first
  badge = badge_el ? badge_el.text.strip : ""
  
  cpn_el = container.css('.prodName.notranslate').first
  cpn = cpn_el ? cpn_el.text.strip : ""

  puts "#{idx + 1}. Title: '#{title}' | Price: '#{price}' | SKU: '#{cpn}' | Badge: '#{badge}'"
end
