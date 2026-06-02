require "test_helper"

class InquiriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = Product.create!(
      title: "Test Product",
      slug: "test-product",
      cpn: "12345",
      price: "10.00",
      min_qty: "100",
      category: "Drinkware"
    )
  end

  test "should create inquiry and format phone with prefix without warnings" do
    assert_difference("Inquiry.count", 1) do
      post inquiries_url, params: {
        product_id: @product.id,
        first_name: "John",
        last_name: "Doe",
        company_name: "Test Corp",
        email: "john.doe@example.com",
        phone_country: "United Kingdom",
        phone: "7777777777",
        country: "UK",
        color: "Blue",
        quantity: "150",
        date_required: "2026-07-01",
        comments: "Test inquiry comments"
      }, as: :json
    end

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]

    inquiry = Inquiry.last
    assert_equal "John", inquiry.first_name
    assert_equal "Doe", inquiry.last_name
    assert_equal "Test Corp", inquiry.company_name
    assert_equal "john.doe@example.com", inquiry.email
    # Phone prefix formatting (+44 for UK)
    assert_equal "+44 7777777777", inquiry.phone
    assert_equal "UK", inquiry.country
    assert_equal "Blue", inquiry.color
    assert_equal 150, inquiry.quantity
    assert_equal Date.parse("2026-07-01"), inquiry.date_required
    assert_equal "Test inquiry comments", inquiry.comments
    assert_equal @product.id, inquiry.product_id
  end

  test "should handle non-existent product" do
    assert_no_difference("Inquiry.count") do
      post inquiries_url, params: {
        product_id: 999999,
        first_name: "John",
        last_name: "Doe",
        company_name: "Test Corp",
        email: "john.doe@example.com",
        phone: "123456"
      }, as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    refute json_response["success"]
    assert_includes json_response["errors"], "Product not found"
  end
end
