class MainHeaderComponent < ViewComponent::Base
  def initialize(query: nil)
    @query = query
    @header_categories = Product.select(:category).distinct.order(:category).pluck(:category).compact
    @header_categories = [
      "Apparel",
      "Desk Accessories",
      "Drinkware",
      "Fidgets",
      "Novelties",
      "Gifts",
      "Bags & Totes",
      "Technology",
      "Wristbands"
    ] if @header_categories.empty?
  end

  def active_class?(path)
    request.path == path ? "active" : ""
  rescue
    ""
  end
end
