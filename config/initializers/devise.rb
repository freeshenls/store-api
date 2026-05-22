# frozen_string_literal: true

Devise.secret_key = '2cf344f2e0a48e98b99ff1edfbccd6a712f9994c44f0b667a2b3e77e3193c812147b06a10909ffc05cbc5ff95537aac830fe928491d123d63a343721558a3f4d'
Devise.email_regexp = Spree::Config[:default_email_regexp]
Devise.setup do |config|
  config.parent_controller = 'StoreDeviseController'
  config.mailer = 'UserMailer'
end
