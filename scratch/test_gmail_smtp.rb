# rails runner script to test Gmail SMTP on ports 465 and 587
require 'net/smtp'

gmail_username = ENV['MAIL_USERNAME'] || 'freeshenls@gmail.com'
gmail_password = ENV['MAIL_PASSWORD'] || 'lpxajobbdkfjikam'
mail_to = ENV['MAIL_TO'] || '1240222852@qq.com'

puts "Testing Gmail SMTP configuration..."
puts "Gmail Username: #{gmail_username}"
puts "Gmail Password: #{gmail_password[0..3]}***#{gmail_password[-3..-1] rescue ''}"

class TestGmailMailer587 < ActionMailer::Base
  self.delivery_method = :smtp
  self.smtp_settings = {
    address:              'smtp.gmail.com',
    port:                 587,
    domain:               'gmail.com',
    user_name:            ENV['MAIL_USERNAME'] || 'freeshenls@gmail.com',
    password:             ENV['MAIL_PASSWORD'] || 'lpxajobbdkfjikam',
    authentication:       :plain,
    enable_starttls_auto: true
  }

  def test_email
    mail(
      from: ENV['MAIL_USERNAME'] || 'freeshenls@gmail.com',
      to: ENV['MAIL_TO'] || '1240222852@qq.com',
      subject: "Gmail SMTP test on port 587 - #{Time.now}",
      body: "Testing Gmail SMTP on port 587 (STARTTLS)"
    )
  end
end

class TestGmailMailer465 < ActionMailer::Base
  self.delivery_method = :smtp
  self.smtp_settings = {
    address:              'smtp.gmail.com',
    port:                 465,
    domain:               'gmail.com',
    user_name:            ENV['MAIL_USERNAME'] || 'freeshenls@gmail.com',
    password:             ENV['MAIL_PASSWORD'] || 'lpxajobbdkfjikam',
    authentication:       :plain,
    ssl:                  true,
    tls:                  true
  }

  def test_email
    mail(
      from: ENV['MAIL_USERNAME'] || 'freeshenls@gmail.com',
      to: ENV['MAIL_TO'] || '1240222852@qq.com',
      subject: "Gmail SMTP test on port 465 - #{Time.now}",
      body: "Testing Gmail SMTP on port 465 (SSL)"
    )
  end
end

puts "\n--- Testing Port 587 ---"
begin
  TestGmailMailer587.test_email.deliver_now
  puts "🎉 Port 587 SUCCESS!"
rescue => e
  puts "❌ Port 587 FAILED!"
  puts "Error: #{e.class} - #{e.message}"
end

puts "\n--- Testing Port 465 ---"
begin
  TestGmailMailer465.test_email.deliver_now
  puts "🎉 Port 465 SUCCESS!"
rescue => e
  puts "❌ Port 465 FAILED!"
  puts "Error: #{e.class} - #{e.message}"
end
