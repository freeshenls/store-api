# frozen_string_literal: true

Devise.secret_key = 'a54dfb4d7d02a695c56ab9c815884a880908c72627e1fa619fe3433c5bf254ec599fdd34892b1a47ed5ef9e5eece739d91213450be40e2f9dcacb982400661e1'
Devise.email_regexp = Spree::Config[:default_email_regexp]
Devise.setup do |config|
  config.parent_controller = 'StoreDeviseController'
  config.mailer = 'UserMailer'
end
