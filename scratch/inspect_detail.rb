# scratch/inspect_detail.rb
require 'nokogiri'

html = File.read("tmp/test_detail.html")
doc = Nokogiri::HTML(html)

puts "--- Meta Description ---"
meta_desc = doc.at_css('meta[name="description"]')
puts meta_desc['content'] if meta_desc

puts "\n--- Checking span.strong.addColon and their containers ---"
doc.css('.strong.addColon, td, th, li, span, div').each do |el|
  text = el.text.strip
  if text.include?("Imprint Method") || text.include?("Production Time") || text.include?("Compliance") || text.include?("Material")
    puts "Element: <#{el.name} class='#{el['class']}'> -> #{text.slice(0, 100)}..."
  end
end
