class ProductGalleryComponent < ViewComponent::Base
  def initialize(images_list:, title:)
    @images_list = images_list
    @title = title
  end
end
