# frozen_string_literal: true

require 'nokogiri'
require 'json'

puts "Testing Nokogiri DB Mapping on first_pen_detail.html..."
detail_path = 'db/dom_data/first_pen_detail.html'
detail_html = File.read(detail_path, encoding: 'utf-8')
doc = Nokogiri::HTML(detail_html)

product = Spree::Product.find_by(name: "Metal Ballpoint Pen With Stylus Tip Rose Gold") || Spree::Product.first
unless product
  puts "Error: No product found in database!"
  exit 1
end

puts "Target Product: #{product.name} (SKU: #{product.sku})"

ActiveRecord::Base.transaction do
  # Clear existing option types and values for testing
  product.variants.destroy_all
  product.option_types.clear
  product.master.option_values.clear

  sku = product.sku
  base_price = product.price.to_f
  shipping_category = product.shipping_category
  stock_location = Spree::StockLocation.active.first

  # 1. Parse static specs from JSON payload
  detail_match = detail_html.match(/DC\.product\s*=\s*(.*?);/m)
  if detail_match
    detail_data = JSON.parse(detail_match[1])
    p_details = detail_data.dig('product', 'product')
    if p_details
      prod_time = p_details['ProductionTime']
      size = p_details['Size']
      
      if prod_time.present?
        prod_time_option = Spree::OptionType.find_or_create_by!(name: 'normal_production_time', presentation: 'Normal Production Time')
        product.option_types << prod_time_option unless product.option_types.include?(prod_time_option)
        prod_time_val = prod_time_option.option_values.find_or_create_by!(
          name: "#{prod_time}_working_days".parameterize.underscore,
          presentation: "#{prod_time} Working Days"
        )
        product.master.option_values << prod_time_val unless product.master.option_values.include?(prod_time_val)
        puts "  Mapped Production Time: #{prod_time_val.presentation}"
      end
      
      if size.present?
        size_option = Spree::OptionType.find_or_create_by!(name: 'product_size', presentation: 'Product Size')
        product.option_types << size_option unless product.option_types.include?(size_option)
        size_val = size_option.option_values.find_or_create_by!(
          name: size.parameterize.underscore,
          presentation: size
        )
        product.master.option_values << size_val unless product.master.option_values.include?(size_val)
        puts "  Mapped Product Size: #{size_val.presentation}"
      end
    end
  end

  # 2. General Options
  options_div = doc.at_css('#dcProduct-options')
  if options_div
    h2s = options_div.css('h2')
    gen_h2 = h2s.find { |h2| h2.text.include?('General Options') }
    
    if gen_h2
      sibling = gen_h2.next_sibling
      while sibling && sibling.name != 'h2'
        if sibling.name == 'div' && sibling.classes.include?('panel')
          option_name = sibling.at_css('.panel-title span')&.text&.strip
          option_values = sibling.css('ul.list-group li span').map(&:text).map(&:strip).reject { |s| s.nil? || s.empty? }.uniq
          
          if option_name.present? && option_values.any?
            puts "  Found general option: #{option_name} => #{option_values.inspect}"
            opt_type = Spree::OptionType.find_or_create_by!(name: option_name.parameterize.underscore, presentation: option_name)
            product.option_types << opt_type unless product.option_types.include?(opt_type)
            
            opt_vals = option_values.map do |val|
              opt_type.option_values.find_or_create_by!(name: val.parameterize.underscore, presentation: val)
            end
            
            opt_vals.each do |opt_value|
              variant_sku = "#{sku}-#{opt_value.name.upcase}"
              variant = product.variants.find_or_initialize_by(sku: variant_sku) do |v|
                v.price = base_price
                v.shipping_category = shipping_category
              end
              variant.option_values = [opt_value]
              variant.save!
              
              if stock_location
                stock_item = stock_location.stock_item_or_create(variant)
                if stock_item.count_on_hand < 1000
                  stock_item.adjust_count_on_hand(1000 - stock_item.count_on_hand)
                end
              end
              puts "    Created variant: #{variant_sku} with option: #{opt_value.presentation}"
            end
          end
        end
        sibling = sibling.next_sibling
      end
    end
  end

  # 3. Imprint Area Options
  imprint_h2 = doc.xpath("//h2[contains(text(), 'Imprint Area Options')]").first
  if imprint_h2
    sibling = imprint_h2.next_sibling
    while sibling && sibling.name != 'h2'
      if sibling.name == 'div' && sibling.classes.include?('panel')
        method_name = sibling.at_css('.panel-title span')&.text&.strip
        if method_name.present?
          imprint_method_option = Spree::OptionType.find_or_create_by!(name: 'imprint_method', presentation: 'Imprint Method')
          product.option_types << imprint_method_option unless product.option_types.include?(imprint_method_option)
          imprint_method_val = imprint_method_option.option_values.find_or_create_by!(
            name: method_name.parameterize.underscore,
            presentation: method_name
          )
          product.master.option_values << imprint_method_val unless product.master.option_values.include?(imprint_method_val)
          puts "  Mapped Imprint Method: #{imprint_method_val.presentation}"
        end
      elsif sibling.name == 'table' || (sibling.name == 'div' && sibling.at_css('table'))
        table = sibling.name == 'table' ? sibling : sibling.at_css('table')
        table.css('tr').each do |row|
          th = row.at_css('th')&.text&.strip
          td = row.at_css('td')&.text&.strip
          if th.present? && td.present?
            option_name = "Imprint #{th}"
            option_key = "imprint_#{th.parameterize.underscore}"
            
            opt_type = Spree::OptionType.find_or_create_by!(name: option_key, presentation: option_name)
            product.option_types << opt_type unless product.option_types.include?(opt_type)
            opt_val = opt_type.option_values.find_or_create_by!(
              name: td.parameterize.underscore,
              presentation: td
            )
            product.master.option_values << opt_val unless product.master.option_values.include?(opt_val)
            puts "  Mapped Imprint Spec: #{option_name} => #{opt_val.presentation}"
          end
        end
      end
      sibling = sibling.next_sibling
    end
  end

  puts "\nRollback transaction to not persist test data..."
  raise ActiveRecord::Rollback
end
puts "Done test run successfully!"
