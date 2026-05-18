# frozen_string_literal: true

Devise.secret_key = '1e839d86a3d2755449d280cebbd06c989e2822c01e09792f401b931f5e82e462b37b8c44842d6ee0a71f48a14212892d016ef6e89177a4db7e7c6e8916f42c07'
Devise.email_regexp = Spree::Config[:default_email_regexp]
Devise.setup do |config|
  config.parent_controller = 'StoreDeviseController'
  config.mailer = 'UserMailer'
end
