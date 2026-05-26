class ProductsController < ApplicationController
  include Alchemy::ControllerActions

  def index
    # Fetch the products page (Page ID 2) to retrieve CMS-managed product elements
    @page = Alchemy::Page.find_by(page_layout: 'products') || Alchemy::Page.find_by(id: 2)
    
    if @page
      @product_cards = @page.elements.where(name: 'product_card').to_a
    else
      @product_cards = []
    end

    # 1. Filter by search query (keyword matching title or category)
    if params[:q].present?
      @query = params[:q].strip
      query_down = @query.downcase
      @product_cards = @product_cards.select do |p|
        p.value_for('title').to_s.downcase.include?(query_down) ||
        p.value_for('category').to_s.downcase.include?(query_down)
      end
    end

    # 2. Filter by category
    if params[:category].present?
      @category_filter = params[:category].strip
      cat_down = @category_filter.downcase
      @product_cards = @product_cards.select do |p|
        p.value_for('category').to_s.downcase.include?(cat_down)
      end
    end
    
    # Extract unique categories from all products for the sidebar filter
    if @page
      all_products = @page.elements.where(name: 'product_card')
      @categories = all_products.map { |p| p.value_for('category').to_s.strip }.uniq.reject(&:empty?)
    else
      @categories = []
    end

    # 5. Array-based Pagination with adjustable page sizes (15, 30, 60, 120)
    allowed_sizes = [15, 30, 60, 120]
    @per_page = params[:per_page].to_i
    @per_page = 15 unless allowed_sizes.include?(@per_page)

    @total_products = @product_cards.count
    @total_pages = [1, (@total_products.to_f / @per_page).ceil].max
    
    @current_page = [1, params[:page].to_i].max
    @current_page = [@current_page, @total_pages].min
    
    start_index = (@current_page - 1) * @per_page
    @all_product_cards = @product_cards
    @product_cards = @all_product_cards[start_index, @per_page] || []
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
