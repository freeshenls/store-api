# scratch/backfill_price_grids.rb
# Run with: bin/rails runner scratch/backfill_price_grids.rb

require 'nokogiri'
require 'open-uri'
require 'json'
require 'thread'

puts "=== Building CPN to Product ID Map ==="
cpn_map = {}

Dir.glob(Rails.root.join("db", "dom_data", "*.html")).each do |html_path|
  html = File.read(html_path)
  doc = Nokogiri::HTML(html)
  
  doc.css('.prodTileWrap .prodPannel').each do |container|
    cpn_el = container.css('.prodName.notranslate').first
    next unless cpn_el
    
    cpn = cpn_el.text.strip.gsub(/[[:space:]]+/, '')
    
    prod_id_el = container.css('input').find { |i| i['id']&.end_with?('_productId') }
    product_id = prod_id_el ? prod_id_el['value'] : nil
    
    if cpn.present? && product_id.present?
      cpn_map[cpn] = product_id
    end
  end
end

puts "Map built with #{cpn_map.size} unique mappings."

puts "\n=== Concurrently Fetching & Backfilling Price Grids ==="
products = Product.all.to_a
total = products.size
queue = Queue.new
products.each { |p| queue << p }

updated_mutex = Mutex.new
updated_count = 0
failed_count = 0
skipped_count = 0
processed_count = 0

thread_count = 25
threads = []

thread_count.times do |t_idx|
  threads << Thread.new do
    until queue.empty?
      product = nil
      begin
        product = queue.pop(true)
      rescue ThreadError
        break
      end
      
      next unless product
      
      cpn_key = product.cpn.to_s.gsub(/[[:space:]]+/, '')
      product_id = cpn_map[cpn_key] || product.cpn[/\d+/]
      
      if product_id.blank?
        updated_mutex.synchronize do
          processed_count += 1
          failed_count += 1
          print "\r[#{processed_count}/#{total}] Skipped (no ID) for: #{product.title[0..20]}..."
        end
        next
      end
      
      url = "https://atozspecialties.espwebsite.com/ProductDetails/?productID=#{product_id}"
      retries = 2
      prices = nil
      
      retries.times do |attempt|
        begin
          html = URI.open(url, "User-Agent" => "Mozilla/5.0", read_timeout: 5, open_timeout: 5).read
          if html =~ /var\s+Product\s*=\s*(\{.*?\});/m
            product_data = JSON.parse($1)
            prices = product_data["Prices"]
            break if prices.present?
          end
        rescue => e
          sleep 0.5 if attempt < retries - 1
        end
      end
      
      updated_mutex.synchronize do
        processed_count += 1
        if prices.present?
          product.update!(price_grid: prices)
          updated_count += 1
          print "\r[#{processed_count}/#{total}] Successfully saved grid for: #{product.title[0..20]}..."
        else
          failed_count += 1
          print "\r[#{processed_count}/#{total}] Failed to load pricing for: #{product.title[0..20]}..."
        end
      end
    end
  end
end

threads.each(&:join)

puts "\n\n🎉 Pricing Backfill Complete!"
puts "Successfully Updated: #{updated_count} products"
puts "Failed / No Price Grid: #{failed_count} products"
puts "Total Products in DB: #{Product.count}"
