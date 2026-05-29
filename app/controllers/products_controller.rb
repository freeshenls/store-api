class ProductsController < ApplicationController
  include Alchemy::ControllerActions

  def index
    # Fetch the products page (Page ID 2) to retrieve CMS-managed product elements
    @page = Alchemy::Page.find_by(page_layout: 'products') || Alchemy::Page.find_by(id: 2)
    
    if @page
      products_relation = @page.elements.where(name: 'product_card')
    else
      products_relation = Alchemy::Element.none
    end

    # 1. Filter by search query (keyword matching title or category) in database
    if params[:q].present?
      @query = params[:q].strip
      matching_ids = Alchemy::Ingredient.where(role: ['title', 'category'])
        .where("LOWER(value) LIKE ?", "%#{@query.downcase}%")
        .select(:element_id)
      products_relation = products_relation.where(id: matching_ids)
    end

    # 2. Filter by category in database
    if params[:category].present?
      @category_filter = params[:category].strip
      matching_cat_ids = Alchemy::Ingredient.where(role: 'category')
        .where("LOWER(value) = ?", @category_filter.downcase)
        .select(:element_id)
      products_relation = products_relation.where(id: matching_cat_ids)
    end

    # 3. Filter by min price in database
    if params[:min_price].present?
      @min_price = params[:min_price].to_f
      matching_price_ids = Alchemy::Ingredient.where(role: 'price')
        .where("CAST(NULLIF(regexp_replace(value, '[^0-9.]', '', 'g'), '') AS numeric) >= ?", @min_price)
        .select(:element_id)
      products_relation = products_relation.where(id: matching_price_ids)
    end

    # 4. Filter by max price in database
    if params[:max_price].present?
      @max_price = params[:max_price].to_f
      matching_price_ids = Alchemy::Ingredient.where(role: 'price')
        .where("CAST(NULLIF(regexp_replace(value, '[^0-9.]', '', 'g'), '') AS numeric) <= ?", @max_price)
        .select(:element_id)
      products_relation = products_relation.where(id: matching_price_ids)
    end
    
    # Extract unique categories from all products for the sidebar filter via SQL pluck
    if @page
      @categories = Alchemy::Ingredient.joins(:element)
        .where(alchemy_elements: { name: 'product_card', page_version_id: products_relation.select(:page_version_id) })
        .where(role: 'category')
        .where.not(value: [nil, ''])
        .distinct
        .pluck(:value)
        .map(&:strip)
        .uniq
    else
      @categories = []
    end

    # 5. Database-level Pagination with adjustable page sizes (15, 30, 60, 120)
    allowed_sizes = [15, 30, 60, 120]
    @per_page = params[:per_page].to_i
    @per_page = 15 unless allowed_sizes.include?(@per_page)

    @total_products = products_relation.count
    @total_pages = [1, (@total_products.to_f / @per_page).ceil].max
    
    @current_page = [1, params[:page].to_i].max
    @current_page = [@current_page, @total_pages].min
    
    start_index = (@current_page - 1) * @per_page
    
    # Expose both total counts and lazy paginated records database-level
    @all_product_cards = products_relation
    @product_cards = products_relation.limit(@per_page).offset(start_index).to_a
  end

  def show
    # Fetch the products page to get CMS-managed product elements
    @page = Alchemy::Page.find_by(page_layout: 'products') || Alchemy::Page.find_by(id: 2)
    slug_or_id = params[:slug].to_s.strip
    
    if @page
      @product_cards = @page.elements.where(name: 'product_card').to_a
    else
      @product_cards = []
    end

    # Find the specific product card by:
    # 1. CMS slug ingredient
    # 2. Parameterized title fallback
    # 3. Database element ID
    @product = @product_cards.find do |p|
      p.value_for('slug').to_s.strip == slug_or_id ||
      p.value_for('title').to_s.parameterize == slug_or_id ||
      p.id.to_s == slug_or_id
    end

    if @product
      # Extract categories list for consistency
      all_products = @page ? @page.elements.where(name: 'product_card') : []
      @categories = all_products.map { |p| p.value_for('category').to_s.strip }.uniq.reject(&:empty?)
      
      # Select 4 related products for the "You May Also Like" ribbon
      @related_products = @product_cards.reject { |p| p.id == @product.id }.sample(4)
    else
      redirect_to products_path, alert: "Product not found."
    end
  end
end
