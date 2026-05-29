# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.

# Create the default administrator account for the Product Importer backend
admin_email = "admin@zevipromotions.com"
admin_password = "password123"

admin_user = User.find_or_initialize_by(email_address: admin_email)
admin_user.assign_attributes(
  password: admin_password,
  password_confirmation: admin_password
)

if admin_user.save
  puts "🎉 Default administrator account seeded successfully!"
  puts "   Email: #{admin_email}"
  puts "   Password: #{admin_password}"
else
  puts "❌ ERROR seeding administrator account: #{admin_user.errors.full_messages.join(', ')}"
end
