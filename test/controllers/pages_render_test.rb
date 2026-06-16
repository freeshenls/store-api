require "test_helper"

class PagesRenderTest < ActionDispatch::IntegrationTest
  setup do
    @product = Product.create!(
      title: "Test Promotional Swag Pen",
      sku: "TEST-PEN",
      slug: "test-promotional-swag-pen",
      guid: "TEST-PEN-GUID",
      category: "Desk Accessories",
      price: "$1.50 each",
      min_qty: "100",
      description: "<p>A high-quality test promotional pen.</p>",
      main_image_url: "https://example.com/test.jpg"
    )
  end

  test "should get homepage" do
    get "/"
    assert_response :success
  end

  test "should get catalog index" do
    get "/products"
    assert_response :success
  end

  test "should get product show page" do
    get "/products/#{@product.guid}/#{@product.slug}"
    assert_response :success
  end

  test "should get artwork tips page" do
    get "/products/artwork_tips"
    assert_response :success
  end

  test "should get login page" do
    get "/session/new"
    assert_response :success
  end
end
