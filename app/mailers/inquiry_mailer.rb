class InquiryMailer < ApplicationMailer
  self.delivery_method = :resend

  def new_inquiry_notification(inquiry)
    @inquiry = inquiry
    @product = inquiry.product
    
    # Attach artwork if present and active
    if @inquiry.artwork.attached?
      begin
        # Download and attach the file stream directly to email
        attachments[@inquiry.artwork.filename.to_s] = @inquiry.artwork.download
      rescue => e
        Rails.logger.error "Failed to attach artwork in InquiryMailer: #{e.message}"
      end
    end

    Resend.api_key = ENV.fetch('RESEND_API_KEY')
    from_email = 'onboarding@resend.dev'
    recipient = ENV.fetch('MAIL_TO')

    mail(
      from: %("New Request Info" <#{from_email}>),
      to: recipient,
      subject: "Request Info From #{@inquiry.email}"
    )
  end
end
