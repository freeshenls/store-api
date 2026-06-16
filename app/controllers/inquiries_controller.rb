class InquiriesController < ApplicationController
  allow_unauthenticated_access

  InquiryData = Struct.new(
    :first_name, :last_name, :company_name, :email, :phone,
    :country, :color, :quantity, :date_required, :comments, :artwork_file,
    keyword_init: true
  )

  def create
    permitted = inquiry_params

    @product = Product.find_by(id: permitted[:product_id])
    if @product.nil?
      render json: { success: false, errors: ["Product not found"] }, status: :unprocessable_entity
      return
    end

    # Validate required fields
    required = %w[first_name last_name company_name email]
    missing = required.select { |f| permitted[f].blank? }
    if missing.any?
      render json: { success: false, errors: ["#{missing.join(', ')} can't be blank"] }, status: :unprocessable_entity
      return
    end

    # Format phone number with country prefix
    phone = permitted[:phone].to_s
    if phone.present?
      prefix = case permitted[:phone_country]
               when "Canada"         then "+1"
               when "United Kingdom" then "+44"
               when "Australia"      then "+61"
               else "+1"
               end
      phone = "#{prefix} #{phone}"
    end

    # Build a plain data object (no DB) using native Struct
    inquiry_data = InquiryData.new(
      first_name:   permitted[:first_name],
      last_name:    permitted[:last_name],
      company_name: permitted[:company_name],
      email:        permitted[:email],
      phone:        phone,
      country:      permitted[:country],
      color:        permitted[:color],
      quantity:     permitted[:quantity],
      date_required: permitted[:date_required],
      comments:     permitted[:comments],
      artwork_file: permitted[:artwork]
    )

    InquiryMailer.new_inquiry_notification(inquiry_data, @product).deliver_now

    render json: { success: true, message: "Thank you! Your inquiry has been submitted successfully. Our team will contact you shortly." }
  end

  private

  def inquiry_params
    params.permit(
      :first_name, :last_name, :company_name, :email,
      :phone, :phone_country, :country, :color,
      :quantity, :date_required, :comments,
      :product_id, :artwork
    )
  end
end
