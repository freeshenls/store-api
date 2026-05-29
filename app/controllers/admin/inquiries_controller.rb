class Admin::InquiriesController < ApplicationController
  layout 'admin'

  def index
    @inquiries = Inquiry.joins(:product).order(created_at: :desc)

    # Simple search keyword matching
    if params[:q].present?
      q = "%#{params[:q].strip.downcase}%"
      @inquiries = @inquiries.where(
        "LOWER(inquiries.first_name) LIKE :q OR " \
        "LOWER(inquiries.last_name) LIKE :q OR " \
        "LOWER(inquiries.email) LIKE :q OR " \
        "LOWER(inquiries.company_name) LIKE :q OR " \
        "LOWER(products.title) LIKE :q",
        q: q
      )
    end

    # Apply offset-based pagination to align with storefront style
    @per_page = 15
    @total_inquiries = @inquiries.count
    @total_pages = [1, (@total_inquiries.to_f / @per_page).ceil].max
    @current_page = [1, params[:page].to_i].max
    @current_page = [@current_page, @total_pages].min
    start_index = (@current_page - 1) * @per_page

    @inquiries = @inquiries.limit(@per_page).offset(start_index)
  end

  def show
    @inquiry = Inquiry.find(params[:id])
  end

  def destroy
    @inquiry = Inquiry.find(params[:id])
    @inquiry.destroy
    redirect_to admin_inquiries_path, notice: "Inquiry successfully deleted."
  end
end
