class InquiryMailer < ApplicationMailer
  default from: -> { %("New Request Info" <#{ENV['MAIL_USERNAME']}>) }

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

    mail(
      to: '1240222852@qq.com',
      subject: "Request Info From #{@inquiry.email}"
    )
  end
end
