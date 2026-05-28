# scratch/parse_content_test.rb
require 'nokogiri'

content_path = '/Users/promote/.gemini/antigravity/brain/2e81f3f9-81db-4b3f-885a-bacbb46aef11/.system_generated/steps/4188/content.md'
unless File.exist?(content_path)
  puts "Content file not found at: #{content_path}"
  exit 1
end

html = File.read(content_path)
doc = Nokogiri::HTML(html)

product_containers = doc.css('.prodTileWrap .prodPannel')
puts "Found #{product_containers.size} product containers."

product_containers.each_with_index do |container, idx|
  puts "--- Product #{idx + 1} ---"
  
  # Image
  img_el = container.css('.prodImg img').first
  image_url = img_el ? (img_el['data-original'] || img_el['src']) : nil
  alt_text = img_el ? img_el['alt'] : nil
  
  # Title
  title_el = container.css('.prodName span[id$=_lblTVProdName]').first
  title = title_el ? title_el.text.strip : nil
  
  # Description
  descr_el = container.css('.prodDescr').first
  description = descr_el ? descr_el.text.strip : nil
  
  # CPN (SKU)
  cpn_el = container.css('.prodName.notranslate').first
  cpn = cpn_el ? cpn_el.text.strip : nil
  
  # Price
  price_el = container.css('.priceLowest span[id$=_lblPrice]').first
  price = price_el ? price_el.text.strip : nil
  
  # Tag / Badge
  badge_el = container.css('.prodTags div').first
  badge = badge_el ? badge_el.text.strip : nil

  puts "Title: #{title}"
  puts "Image URL: #{image_url}"
  puts "Alt: #{alt_text}"
  puts "Description: #{description[0..100]}..." if description
  puts "CPN: #{cpn}"
  puts "Price: #{price}"
  puts "Badge/Tag: #{badge}"
  
  break if idx >= 2
end
