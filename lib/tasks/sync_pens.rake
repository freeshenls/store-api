# frozen_string_literal: true

require 'open-uri'
require 'json'
require 'nokogiri'


namespace :sync do
  desc "Synchronize 120 Pens catalog from local DOM files"
  task pens: :environment do
    catalog_path = "db/dom_data/pens_catalog.html"

    unless File.exist?(catalog_path)
      puts "Error: Catalog DOM file not found at #{catalog_path}"
      puts "Please run the subagent to capture it first."
      exit 1
    end

    puts "Parsing catalog DOM file: #{catalog_path}..."
    html = File.read(catalog_path, encoding: 'utf-8')
    match = html.match(/window\.DC\.catalog\s*=\s*(.*?);<\/script>/m)

    unless match
      puts "Error: Could not find window.DC.catalog in #{catalog_path}"
      exit 1
    end

    catalog_data = JSON.parse(match[1])
    products_records = catalog_data.dig('results', 'products', 'records') || []

    if products_records.empty?
      puts "Error: No product records found inside catalog DOM data."
      exit 1
    end

    puts "Successfully parsed #{products_records.size} pens from catalog DOM!"

    # Initialize categories taxonomy
    puts "\nConfiguring Categories Taxonomy..."
    categories_taxonomy = Spree::Taxonomy.find_or_create_by!(name: "Categories")
    categories_root = categories_taxonomy.root

    # Find or create 'Pens' taxon
    pens_taxon = Spree::Taxon.find_or_create_by!(
      name: "Pens",
      taxonomy: categories_taxonomy,
      parent: categories_root
    )
    puts "Taxon 'Pens' ready (ID: #{pens_taxon.id})"

    shipping_category = Spree::ShippingCategory.find_or_create_by!(name: "Default")
    stock_location = Spree::StockLocation.active.first

    products_records.each_with_index do |p_rec, idx|
      name = p_rec['ItemName']
      sku = p_rec['SuplItemNo'] || "PEN-#{p_rec['SupplierItemGUID']}"
      description = p_rec['Description'] || "High-quality custom pen for sports, corporate, and promotional events."
      base_image_url = p_rec['ImagePath']
      min_qty = p_rec['MinQty'].to_i
      base_price = p_rec['MinRetail'].to_f
      base_price = 1.0 if base_price <= 0.0 # fallback default price
      
      desc_path = "db/dom_data/pens/#{idx + 1}_description.html"
      opts_path = "db/dom_data/pens/#{idx + 1}_product_options.html"
      single_path = "db/dom_data/pens/#{idx + 1}_detail.html"

      has_split_dom = File.exist?(desc_path) && File.exist?(opts_path)
      has_single_dom = File.exist?(single_path)
      has_detail_dom = has_split_dom || has_single_dom

      puts "\n[#{idx + 1}/#{products_records.size}] Synchronizing: #{name} (SKU: #{sku})"

      # 1. Initialize or find the product
      product = Spree::Product.find_or_initialize_by(name: name) do |p|
        p.shipping_category = shipping_category
        p.available_on = Time.current
      end

      product.sku = sku
      product.description = description

      # 2. Check if we have dynamic DOM file(s) for this product to extract rich data
      if has_detail_dom
        if has_split_dom
          puts "  Parsing detailed split DOMs from #{desc_path} and #{opts_path}..."
          detail_html = File.read(desc_path, encoding: 'utf-8')
          options_html = File.read(opts_path, encoding: 'utf-8')
        else
          puts "  Parsing detailed single DOM from #{single_path}..."
          detail_html = File.read(single_path, encoding: 'utf-8')
          options_html = detail_html
        end
          
          # Clean up any pre-existing dynamic option types and variants for a clean reload
          product.variants.destroy_all
          product.option_types.clear
          product.master.option_values.clear

          detail_match = detail_html.match(/DC\.product\s*=\s*(.*?);/m)
          
          if detail_match
            detail_data = JSON.parse(detail_match[1])
            p_details = detail_data.dig('product', 'product')
            
            if p_details
              # Override description with detailed one
              product.description = p_details['Description'] if p_details['Description'].present?
              
              # Extract correct base price from the first version's first price tier
              first_version = p_details['versions']&.first
              if first_version && first_version['QuantityPrices'].present?
                base_price = first_version['QuantityPrices'].first['RetailPrice'].to_f
              end

              # Map static specs (ProductionTime, Size) to Spree OptionTypes on the master variant
              prod_time = p_details['ProductionTime']
              size = p_details['Size']
              
              if prod_time.present?
                prod_time_option = Spree::OptionType.find_or_create_by!(name: 'normal_production_time', presentation: 'Normal Production Time')
                product.option_types << prod_time_option unless product.option_types.include?(prod_time_option)
                
                presentation_val = prod_time.to_s
                presentation_val += " Working Days" unless presentation_val.downcase.include?("working days")
                prod_time_val = prod_time_option.option_values.find_or_create_by!(
                  name: "#{prod_time}_working_days".parameterize.underscore,
                  presentation: presentation_val
                )
                product.master.option_values << prod_time_val unless product.master.option_values.include?(prod_time_val)
              end
              
              if size.present?
                size_option = Spree::OptionType.find_or_create_by!(name: 'product_size', presentation: 'Product Size')
                product.option_types << size_option unless product.option_types.include?(size_option)
                size_val = size_option.option_values.find_or_create_by!(
                  name: size.parameterize.underscore,
                  presentation: size
                )
                product.master.option_values << size_val unless product.master.option_values.include?(size_val)
              end
            end
          end

          # Parse options using Nokogiri
          doc = Nokogiri::HTML(detail_html)
          options_doc = Nokogiri::HTML(options_html)

          # Mapped general options (e.g. Product Color) to variants
          options_div = options_doc.at_css('#dcProduct-options')
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
                    # Use 'product_color' style naming to align with color styling helpers
                    opt_key = option_name.downcase.include?('color') ? 'product_color' : option_name.parameterize.underscore
                    opt_type = Spree::OptionType.find_or_create_by!(name: opt_key, presentation: option_name)
                    product.option_types << opt_type unless product.option_types.include?(opt_type)
                    
                    opt_vals = option_values.map do |val|
                      opt_type.option_values.find_or_create_by!(name: val.parameterize.underscore, presentation: val)
                    end
                    
                    # Create child variants for these option values
                    opt_vals.each do |opt_value|
                      variant_sku = "#{sku}-#{opt_value.name.upcase}"
                      variant = product.variants.find_or_initialize_by(sku: variant_sku) do |v|
                        v.price = base_price
                        v.shipping_category = shipping_category
                      end
                      variant.option_values = [opt_value]
                      variant.save!
                      
                      # Explicitly save the default price record in USD for Solidus variant selectors
                      p_rec = variant.prices.find_or_initialize_by(currency: 'USD')
                      p_rec.amount = base_price
                      p_rec.save!
                      
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

          # Parse imprint area options (Imprint Method, Imprint Specs)
          imprint_h2 = options_doc.xpath("//h2[contains(text(), 'Imprint Area Options')]").first
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

      else
        puts "  Warning: Detailed DOM not found at #{detail_path}. Using catalog grid defaults."
      end

      product.price = base_price
      product.save!

      # 3. Associate with 'Pens' taxon
      unless product.taxons.include?(pens_taxon)
        product.taxons << pens_taxon
      end

      # 4. Configure master variant stock and base price
      master_variant = product.master
      master_variant.price = base_price
      master_variant.save!

      if stock_location
        stock_item = stock_location.stock_item_or_create(master_variant)
        if stock_item.count_on_hand < 1000
          stock_item.adjust_count_on_hand(1000 - stock_item.count_on_hand)
        end
      end

      # 5. Populate volume pricing rules
      master_variant.volume_prices.destroy_all

      if has_detail_dom && p_details
        # Parse all detailed quantity-tiered prices from this pen's detail DOM
        first_version = p_details['versions']&.first
        if first_version && first_version['QuantityPrices'].present?
          prices_tiers = first_version['QuantityPrices'].sort_by { |qp| qp['Quantity'].to_i }
          
          prices_tiers.each_with_index do |qp, t_idx|
            qty_min = qp['Quantity'].to_i
            range_str = if t_idx < prices_tiers.size - 1
                          qty_max = prices_tiers[t_idx + 1]['Quantity'].to_i - 1
                          "#{qty_min}..#{qty_max}"
                        else
                          "#{qty_min}+"
                        end
            unit_price = qp['RetailPrice'].to_f
            
            puts "  Adding Rich Volume Price Tier: #{range_str} => $#{unit_price}"
            master_variant.volume_prices.create!(
              range: range_str,
              amount: unit_price,
              discount_type: "price",
              position: t_idx + 1
            )
          end
        end
      else
        # For the remaining 119 products, create a basic default volume price tier
        range_str = "#{min_qty}+"
        puts "  Adding Default Volume Price Tier: #{range_str} => $#{base_price}"
        master_variant.volume_prices.create!(
          range: range_str,
          amount: base_price,
          discount_type: "price",
          position: 1
        )
      end

      # 6. Import images
      if has_detail_dom && p_details && p_details['Images'].present?
        # For this product, download and attach all detailed images in the gallery
        p_details['Images'].each_with_index do |img_data, img_idx|
          img_url = img_data['imagePathLarge'] || img_data['imagePath']
          next if img_url.blank?
          
          filename = File.basename(URI.parse(img_url).path) rescue "pen_image_#{img_idx}.jpg"
          filename = "pen_image_#{img_idx}.jpg" if filename.blank? || filename == "/"
          
          # Skip if already attached
          already_attached = product.gallery.images.any? { |spree_img| spree_img.attachment.filename.to_s == filename }
          if already_attached
            puts "  Gallery image #{img_idx + 1} already attached. Skipping."
            next
          end
          
          begin
            puts "  Downloading detailed image #{img_idx + 1}/#{p_details['Images'].size}: #{img_url}"
            image_io = URI.open(img_url, "User-Agent" => "Mozilla/5.0", :open_timeout => 5, :read_timeout => 5)
            
            spree_image = Spree::Image.new
            spree_image.attachment.attach(io: image_io, filename: filename)
            spree_image.viewable = master_variant
            spree_image.save!
            puts "    Successfully attached detailed image #{img_idx + 1}."
          rescue => e
            puts "    Warning: Failed to import detailed image #{img_idx + 1}. Error: #{e.message}"
          end
        end
      elsif base_image_url.present? && product.gallery.images.empty?
        # For other products, download the main thumbnail image
        filename = File.basename(URI.parse(base_image_url).path) rescue "pen_image.jpg"
        filename = "pen_image.jpg" if filename.blank? || filename == "/"
        
        begin
          puts "  Downloading main image: #{base_image_url}"
          image_io = URI.open(base_image_url, "User-Agent" => "Mozilla/5.0", :open_timeout => 5, :read_timeout => 5)
          
          spree_image = Spree::Image.new
          spree_image.attachment.attach(io: image_io, filename: filename)
          spree_image.viewable = master_variant
          spree_image.save!
          puts "    Successfully attached main image."
        rescue => e
          puts "    Warning: Failed to import main image. Error: #{e.message}"
        end
      end
    end

    puts "\nCatalog sync successfully completed! Total products synchronized from DOM: #{products_records.size}"
  end
end
