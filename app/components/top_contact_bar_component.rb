class TopContactBarComponent < ViewComponent::Base
  def initialize(phone_number: "(714) 857-0010", email_address: "info@zevipromotions.com")
    @phone_number = phone_number
    @email_address = email_address
  end
end
