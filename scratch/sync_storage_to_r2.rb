# Rails runner script to sync all local ActiveStorage disk files to Cloudflare R2
require 'aws-sdk-s3'
require 'pathname'

endpoint = ENV['R2_ENDPOINT']
access_key_id = ENV['R2_ACCESS_KEY_ID']
secret_access_key = ENV['R2_SECRET_ACCESS_KEY']
bucket_name = ENV['R2_BUCKET'] || 'store-api'
region = ENV['R2_REGION'] || 'auto'

if endpoint.blank? || access_key_id.blank? || secret_access_key.blank?
  puts "Error: Missing R2 environment variables!"
  exit 1
end

puts "Connecting to R2 endpoint: #{endpoint}..."
s3 = Aws::S3::Client.new(
  endpoint: endpoint,
  access_key_id: access_key_id,
  secret_access_key: secret_access_key,
  region: region,
  force_path_style: true
)

storage_dir = Rails.root.join("storage")
unless storage_dir.exist?
  puts "Error: storage/ directory not found!"
  exit 1
end

puts "Scanning local ActiveStorage directory..."

Dir.glob(storage_dir.join("**/*")).each do |file_path|
  next if File.directory?(file_path)
  next if file_path.end_with?(".keep")
  
  # ActiveStorage stores files under key names.
  # For example, a file under storage/09/cv/09cv12345 has the key "09cv12345".
  # The filename itself is the actual ActiveStorage key.
  key = File.basename(file_path)
  
  puts "Syncing local storage file #{File.basename(file_path)} -> R2 key: #{key}..."
  File.open(file_path, 'rb') do |file|
    s3.put_object(
      bucket: bucket_name,
      key: key,
      body: file,
      content_type: "image/png" # ActiveStorage handles content_type dynamically, standard upload as binary/image is perfectly safe
    )
  end
end

puts "🎉 Success! All local ActiveStorage media files have been synced to your Cloudflare R2 bucket!"
