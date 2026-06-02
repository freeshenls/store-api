class InquiriesController < ApplicationController
  allow_unauthenticated_access

  def create
    permitted = inquiry_params
    @product = Product.find_by(id: permitted[:product_id])
    if @product.nil?
      render json: { success: false, errors: ["Product not found"] }, status: :unprocessable_entity
      return
    end

    inquiry_attrs = permitted.except(:product_id, :phone_country, :artwork)
    
    # Format phone number to include prefix based on phone_country if present
    if permitted[:phone].present?
      phone_prefix = case permitted[:phone_country]
                     when "Canada" then "+1"
                     when "United Kingdom" then "+44"
                     when "Australia" then "+61"
                     else "+1"
                     end
      inquiry_attrs[:phone] = "#{phone_prefix} #{permitted[:phone]}"
    end

    @inquiry = @product.inquiries.new(inquiry_attrs)

    # Attach optional artwork file
    if permitted[:artwork].present?
      @inquiry.artwork.attach(permitted[:artwork])
    end

    if @inquiry.save
      begin
        InquiryMailer.new_inquiry_notification(@inquiry).deliver_now
      rescue => e
        Rails.logger.error "Failed to send inquiry email notification: #{e.message}"
      end

      render json: { success: true, message: "Thank you! Your inquiry has been submitted successfully. Our team will contact you shortly." }
    else
      render json: { success: false, errors: @inquiry.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def inquiry_params
    params.permit(
      :first_name,
      :last_name,
      :company_name,
      :email,
      :phone,
      :country,
      :color,
      :quantity,
      :date_required,
      :comments,
      :product_id,
      :phone_country,
      :artwork
    )
  end
end
