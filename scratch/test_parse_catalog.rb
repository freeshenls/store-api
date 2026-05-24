# frozen_string_literal: true

require 'json'

puts "Testing DOM Parsing Logic..."

# 1. Parse Catalog
catalog_path = 'db/dom_data/pens_catalog.html'
html = File.read(catalog_path, encoding: 'utf-8')
match = html.match(/window\.DC\.catalog\s*=\s*(.*?);<\/script>/m)

unless match
  puts "Error: Could not find window.DC.catalog in #{catalog_path}"
  exit 1
end

data = JSON.parse(match[1])
records = data['results']['products']['records']
puts "Parsed catalog successfully! Total records found: #{records.size}"

first_rec = records.first
puts "\nFirst record in catalog DOM:"
puts "  Name: #{first_rec['ItemName']}"
puts "  SKU: #{first_rec['SuplItemNo']}"
puts "  Min Retail: $#{first_rec['MinRetail']}"
puts "  Min Qty: #{first_rec['MinQty']}"
puts "  ImagePath: #{first_rec['ImagePath']}"
puts "  Link: #{first_rec['Link']}"

# 2. Parse first product details DOM
detail_path = 'db/dom_data/first_pen_detail.html'
detail_html = File.read(detail_path, encoding: 'utf-8')
detail_match = detail_html.match(/DC\.product\s*=\s*(.*?);/m)

unless detail_match
  puts "Error: Could not find DC.product in #{detail_path}"
  exit 1
end

detail_data = JSON.parse(detail_match[1])
p_details = detail_data['product']['product']

puts "\nFirst record details DOM parsing:"
puts "  Name: #{p_details['ItemName']}"
puts "  Description: #{p_details['Description']}"
puts "  Images found: #{p_details['Images'].size}"
p_details['Images'].each_with_index do |img, idx|
  puts "    Image #{idx+1}: #{img['imagePathLarge'] || img['imagePath']}"
end

first_version = p_details['versions'].first
puts "  Volume Price Tiers found: #{first_version['QuantityPrices'].size}"
first_version['QuantityPrices'].each do |qp|
  puts "    Qty: #{qp['Quantity']} => Price: $#{qp['RetailPrice']}"
end
