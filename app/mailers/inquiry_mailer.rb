class InquiryMailer < ApplicationMailer
  self.delivery_method = :resend

  def new_inquiry_notification(inquiry_data, product)
    @inquiry = inquiry_data
    @product = product

    # Attach artwork file if provided
    if @inquiry.artwork_file.present?
      begin
        attachments[@inquiry.artwork_file.original_filename] = @inquiry.artwork_file.read
      rescue => e
        Rails.logger.error "Failed to attach artwork in InquiryMailer: #{e.message}"
      end
    end

    Resend.api_key = ENV.fetch('RESEND_API_KEY')
    from_email = 'onboarding@resend.dev'
    recipient  = ENV.fetch('MAIL_TO')

    mail(
      from:    %("New Request Info" <#{from_email}>),
      to:      recipient,
      subject: "Request Info From #{@inquiry.email}"
    )
  end
end
