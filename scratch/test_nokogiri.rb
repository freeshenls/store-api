# frozen_string_literal: true

require 'nokogiri'
require 'json'

puts "Testing Nokogiri Parsing on first_pen_detail.html..."
html_path = 'db/dom_data/first_pen_detail.html'
html = File.read(html_path, encoding: 'utf-8')
doc = Nokogiri::HTML(html)

# 1. Parse static specs from JSON payload
detail_match = html.match(/DC\.product\s*=\s*(.*?);/m)
if detail_match
  detail_data = JSON.parse(detail_match[1])
  p_details = detail_data.dig('product', 'product')
  if p_details
    prod_time = p_details['ProductionTime']
    size = p_details['Size']
    puts "  Production Time (from JSON): #{prod_time} Working Days" if prod_time
    puts "  Product Size (from JSON): #{size}" if size
  end
end

# 3. General Options
puts "\nGeneral Options:"
options_div = doc.at_css('#dcProduct-options')
if options_div
  # Find all panels under General Options header
  # General Options is the first h2. Let's find h2 elements.
  h2s = options_div.css('h2')
  gen_h2 = h2s.find { |h2| h2.text.include?('General Options') }
  
  if gen_h2
    # Find panels between General Options and next h2
    sibling = gen_h2.next_sibling
    while sibling && sibling.name != 'h2'
      if sibling.name == 'div' && sibling.classes.include?('panel')
        option_name = sibling.at_css('.panel-title span')&.text&.strip
        option_values = sibling.css('ul.list-group li span').map(&:text).map(&:strip).reject { |s| s.nil? || s.empty? }.uniq
        puts "  Option: #{option_name} => #{option_values.inspect}"
      end
      sibling = sibling.next_sibling
    end
  end
else
  puts "  options_div: NOT found"
end

# 4. Imprint Area Options
puts "\nImprint Area Options:"
imprint_h2 = doc.xpath("//h2[contains(text(), 'Imprint Area Options')]").first
if imprint_h2
  sibling = imprint_h2.next_sibling
  while sibling && sibling.name != 'h2'
    if sibling.name == 'div' && sibling.classes.include?('panel')
      method_name = sibling.at_css('.panel-title span')&.text&.strip
      puts "  Imprint Method: #{method_name}"
    elsif sibling.name == 'table' || (sibling.name == 'div' && sibling.at_css('table'))
      # Standard Spec table
      table = sibling.name == 'table' ? sibling : sibling.at_css('table')
      table.css('tr').each do |row|
        th = row.at_css('th')&.text&.strip
        td = row.at_css('td')&.text&.strip
        puts "  Imprint Spec: #{th} => #{td}" if th && td
      end
    end
    sibling = sibling.next_sibling
  end
end
