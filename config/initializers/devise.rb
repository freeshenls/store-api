# frozen_string_literal: true

Devise.secret_key = '79ef04956a859412e2a3dc14cb058d2a69e43b935250f5ba980919ebf2c6dd62db47f5eaf72fbd4a1ef04838213bcfb91d4981bbc73d492995f09fc6766f6a24'
Devise.email_regexp = Spree::Config[:default_email_regexp]
Devise.setup do |config|
  config.parent_controller = 'StoreDeviseController'
  config.mailer = 'UserMailer'
end
