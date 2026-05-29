class Admin::ImportsController < ApplicationController
  layout "admin"
  
  # Protect controller from CSRF
  protect_from_forgery with: :exception

  def index
    # Load all products currently in the database to display in a neat list with pagination
    products_relation = Product.all.order(created_at: :desc)
    
    @per_page = 15
    @total_products = products_relation.count
    @total_pages = [1, (@total_products.to_f / @per_page).ceil].max
    
    @current_page = [1, params[:page].to_i].max
    @current_page = [@current_page, @total_pages].min
    
    start_index = (@current_page - 1) * @per_page
    
    @products = products_relation.limit(@per_page).offset(start_index).to_a
  end

  def create
    uploaded_file = params[:file]
    
    if uploaded_file.blank?
      redirect_to admin_imports_path, alert: "Please select an Excel (.xlsx) file to upload."
      return
    end

    # Check file extension
    extname = File.extname(uploaded_file.original_filename).downcase
    if extname != ".xlsx"
      redirect_to admin_imports_path, alert: "Invalid file format. Please upload a valid Excel workbook (.xlsx)."
      return
    end

    require 'roo'
    require 'open-uri'

    imported_count = 0
    errors_log = []

    begin
      # Open uploaded temp file natively using Roo
      xlsx = Roo::Spreadsheet.open(uploaded_file.path)
      
      # Try to locate sheets named "Products" or fall back to the first sheet
      sheet = xlsx.sheet("Products") rescue nil
      sheet ||= xlsx.sheet(0)

      # Extract headers
      headers = sheet.row(1).map(&:to_s).map(&:strip)
      
      # Minimum required headers validation
      unless headers.include?("cpn") && headers.include?("title")
        redirect_to admin_imports_path, alert: "Invalid template. The spreadsheet MUST contain at least 'cpn' and 'title' header columns."
        return
      end

      # Iterate through each row in sheet (from row index 2 to the end)
      (2..sheet.last_row).each do |row_idx|
        row_data = sheet.row(row_idx)
        
        # Skip empty rows
        next if row_data.compact.blank?

        # Map row data to headers hash
        row = Hash[headers.zip(row_data)]
        
        cpn = row['cpn']&.to_s&.strip
        title = row['title']&.to_s&.strip
        category = row['category']&.to_s&.strip
        price = row['price']&.to_s&.strip
        old_price = row['old_price']&.to_s&.strip
        min_qty = row['min_qty']&.to_s&.strip
        badge = row['badge']&.to_s&.strip
        section = row['section']&.to_s&.strip || 'New Products'
        
        # Image URLs (1 to 5)
        image_urls = [
          row['image_url_1'],
          row['image_url_2'],
          row['image_url_3'],
          row['image_url_4'],
          row['image_url_5']
        ].compact.map(&:to_s).map(&:strip).select(&:present?)
        
        # Accordions
        product_detail = row['product_detail']&.to_s
        imprint = row['imprint']&.to_s
        production_shipping = row['production_shipping']&.to_s
        safety_compliance = row['safety_compliance']&.to_s

        if cpn.blank? || title.blank?
          errors_log << "Row #{row_idx}: CPN or Title is missing."
          next
        end

        # Find or initialize native Product by CPN
        product = Product.find_or_initialize_by(cpn: cpn)
        product.assign_attributes(
          title: title,
          category: category,
          price: price,
          old_price: old_price,
          min_qty: min_qty,
          badge: badge,
          section: section,
          product_detail: product_detail,
          imprint: imprint,
          production_shipping: production_shipping,
          safety_compliance: safety_compliance
        )

        # Generate slug natively if new
        if product.new_record?
          product.slug = title.parameterize
        end

        if product.save
          # Process images if they are provided in Excel
          if image_urls.any?
            # Purge old images if they exist to prevent duplicates
            product.images.purge if product.images.attached?

            image_urls.each_with_index do |image_url, img_idx|
              begin
                ext = File.extname(URI.parse(image_url).path)
                ext = ".jpg" if ext.blank?
                temp_filename = "xlsx_import_upload_#{SecureRandom.hex(4)}_#{img_idx + 1}#{ext}"
                temp_filepath = Rails.root.join("tmp", temp_filename)
                
                # Build fallback URLs (jpgo -> jpeg -> jpgb -> jpgt) to prevent 500 download failures
                urls_to_try = [image_url]
                if image_url.include?("/images/jpgo/")
                  urls_to_try << image_url.gsub("/images/jpgo/", "/images/jpeg/")
                  urls_to_try << image_url.gsub("/images/jpgo/", "/images/jpgb/")
                  urls_to_try << image_url.gsub("/images/jpgo/", "/images/jpgt/")
                end
                urls_to_try.uniq!
                
                success = false
                last_error = nil
                
                urls_to_try.each do |url|
                  begin
                    URI.open(url, "User-Agent" => "Mozilla/5.0", read_timeout: 8, open_timeout: 8) do |stream|
                      File.open(temp_filepath, "wb") do |f|
                        f.write(stream.read)
                      end
                    end
                    success = true
                    break
                  rescue => e
                    last_error = e
                  end
                end
                
                raise last_error unless success
                
                # Attach to ActiveStorage
                File.open(temp_filepath, "rb") do |file|
                  product.images.attach(
                    io: file,
                    filename: "#{product.slug}_#{img_idx + 1}#{ext}",
                    content_type: ext == ".png" ? "image/png" : "image/jpeg"
                  )
                end
                
                File.delete(temp_filepath) if File.exist?(temp_filepath)
              rescue => e
                errors_log << "Row #{row_idx} Image #{img_idx + 1}: Failed to download/attach. #{e.message}"
                File.delete(temp_filepath) if File.exist?(temp_filepath) rescue nil
              end
            end
          end
          imported_count += 1
        else
          errors_log << "Row #{row_idx} (#{title}): Save failed - #{product.errors.full_messages.join(', ')}"
        end
      end

      # Success redirect
      if errors_log.empty?
        redirect_to admin_imports_path, notice: "Successfully imported #{imported_count} products from the Excel workbook!"
      else
        redirect_to admin_imports_path, notice: "Import completed with issues. Imported #{imported_count} products.", alert: "Import warnings:\n#{errors_log.first(5).join("\n")}"
      end

    rescue => e
      redirect_to admin_imports_path, alert: "ERROR parsing Excel file: #{e.message}"
    end
  end
end
