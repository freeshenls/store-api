class InquiriesController < ApplicationController
  allow_unauthenticated_access

  def create
    @product = Product.find_by(id: params[:product_id])
    if @product.nil?
      render json: { success: false, errors: ["Product not found"] }, status: :unprocessable_entity
      return
    end

    @inquiry = @product.inquiries.new(inquiry_params)

    # Attach optional artwork file
    if params[:artwork].present?
      @inquiry.artwork.attach(params[:artwork])
    end

    if @inquiry.save
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
      :comments
    )
  end
end
