class ProductsController < ApplicationController
  allow_unauthenticated_access
  def index
    products_relation = Product.all

    # 1. Filter by search query (keyword matching title, category, or cpn) in database
    if params[:q].present?
      @query = params[:q].strip
      products_relation = products_relation.where(
        "LOWER(title) LIKE :q OR LOWER(category) LIKE :q OR LOWER(cpn) LIKE :q",
        q: "%#{@query.downcase}%"
      )
    end

    # 2. Filter by category in database
    if params[:category].present?
      @category_filter = params[:category].strip
      products_relation = products_relation.where("LOWER(category) = ?", @category_filter.downcase)
    end

    # 3. Filter by min price in database using Postgres regex casting
    if params[:min_price].present?
      @min_price = params[:min_price].to_f
      products_relation = products_relation.where(
        "CAST(NULLIF(regexp_replace(price, '[^0-9.]', '', 'g'), '') AS numeric) >= ?",
        @min_price
      )
    end

    # 4. Filter by max price in database using Postgres regex casting
    if params[:max_price].present?
      @max_price = params[:max_price].to_f
      products_relation = products_relation.where(
        "CAST(NULLIF(regexp_replace(price, '[^0-9.]', '', 'g'), '') AS numeric) <= ?",
        @max_price
      )
    end
    
    # Extract unique categories from all products for the sidebar filter
    @categories = get_enriched_categories

    # 5. Database-level Pagination with adjustable page sizes (15, 30, 60, 120)
    allowed_sizes = [15, 30, 60, 120]
    @per_page = params[:per_page].to_i
    @per_page = 15 unless allowed_sizes.include?(@per_page)

    @total_products = products_relation.count
    @total_pages = [1, (@total_products.to_f / @per_page).ceil].max
    
    @current_page = [1, params[:page].to_i].max
    @current_page = [@current_page, @total_pages].min
    
    start_index = (@current_page - 1) * @per_page
    
    @all_product_cards = products_relation
    @product_cards = products_relation.limit(@per_page).offset(start_index).to_a
  end

  def show
    slug_or_id = params[:slug].to_s.strip
    @product = Product.find_by(slug: slug_or_id) || Product.find_by(id: slug_or_id)

    if @product
      @categories = get_enriched_categories
      @related_products = Product.where.not(id: @product.id).limit(4).to_a
      
      # Fill up related products to exactly 4 if needed
      if @related_products.size < 4
        needed = 4 - @related_products.size
        extra_products = Product.where.not(id: [@product.id] + @related_products.map(&:id)).limit(needed).to_a
        @related_products += extra_products
      end
    else
      redirect_to products_path, alert: "Product not found."
    end
  end

  def artwork_tips
    # Renders the graphic designer artwork tips template
  end

  private

  def get_enriched_categories
    cats = Product.select(:category).distinct.order(:category).pluck(:category).compact
    cats.any? ? cats : [
      "Apparel",
      "Desk Accessories",
      "Drinkware",
      "Fidgets",
      "Novelties",
      "Gifts",
      "Bags & Totes",
      "Technology",
      "Wristbands"
    ]
  end
end
