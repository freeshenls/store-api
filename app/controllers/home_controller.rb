class HomeController < ApplicationController
  allow_unauthenticated_access
  def index
    @trending_products = Product.all.limit(6)
    
    # The exact 9 categories of the system
    @categories = [
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
