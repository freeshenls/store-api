# config/initializers/mail.rb

if ENV['MAIL_USERNAME'].present? && ENV['MAIL_PASSWORD'].present?
  ActionMailer::Base.delivery_method = :smtp
  ActionMailer::Base.smtp_settings = {
    address:              'smtp.163.com',
    port:                 465,
    domain:               '163.com',
    user_name:            ENV['MAIL_USERNAME'],
    password:             ENV['MAIL_PASSWORD'],
    authentication:       :login,
    ssl:                  true,
    tls:                  true
  }
else
  # Fallback to test delivery method if ENV parameters are missing (e.g. local dev without env variables)
  ActionMailer::Base.delivery_method = :test
end
