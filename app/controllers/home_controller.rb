class HomeController < ApplicationController
  allow_unauthenticated_access
  def index
    @trending_products = Product.all.limit(6)
    
    @categories = Product.select(:category).distinct.order(:category).pluck(:category).compact
    @categories = ["Apparel", "Desk Accessories", "Drinkware", "Fidgets", "Novelties", "Gifts", "Bags & Totes", "Technology", "Wristbands"] if @categories.empty?
  end
end
