# Rails runner script to compile and upload all precompiled assets to Cloudflare R2
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

# 1. Precompile assets to ensure everything is latest
puts "Compiling assets using bin/rails assets:precompile..."
system("bin/rails assets:precompile")

puts "Connecting to R2 endpoint: #{endpoint}..."
s3 = Aws::S3::Client.new(
  endpoint: endpoint,
  access_key_id: access_key_id,
  secret_access_key: secret_access_key,
  region: region,
  force_path_style: true
)

upload_dirs = {
  "public/assets" => "assets",
  "public/sales" => "sales"
}

upload_dirs.each do |dir_name, prefix|
  dir_path = Rails.root.join(dir_name)
  unless dir_path.exist?
    puts "Warning: #{dir_name} directory not found. Skipping..."
    next
  end

  puts "Uploading files from #{dir_name} to R2 bucket '#{bucket_name}' under '#{prefix}/'..."

  Dir.glob(dir_path.join("**/*")).each do |file_path|
    next if File.directory?(file_path)
    
    relative_path = Pathname.new(file_path).relative_path_from(dir_path).to_s
    key = "#{prefix}/#{relative_path}"
    
    # Determine content type
    content_type = case File.extname(file_path).downcase
    when '.css'  then 'text/css'
    when '.js'   then 'text/javascript'
    when '.woff2'then 'font/woff2'
    when '.woff' then 'font/woff'
    when '.ttf'  then 'font/ttf'
    when '.png'  then 'image/png'
    when '.jpg', '.jpeg' then 'image/jpeg'
    when '.svg'  then 'image/svg+xml'
    when '.gif'  then 'image/gif'
    when '.html' then 'text/html'
    when '.pdf'  then 'application/pdf'
    when '.json' then 'application/json'
    when '.map'  then 'application/json'
    else
      'application/octet-stream'
    end

    # Check if the file already exists in Cloudflare R2 bucket to prevent redundant uploading
    file_exists = false
    begin
      s3.head_object(bucket: bucket_name, key: key)
      file_exists = true
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      # File is not present in R2, we need to upload
    rescue => e
      if e.class.name.include?("NotFound") || e.class.name.include?("NoSuchKey") || (e.respond_to?(:context) && e.context.response.status_code == 404)
        # Not found (alternate exception form)
      else
        puts "WARNING: Error checking existence of #{key}: #{e.message}"
      end
    end

    if file_exists
      puts "Skipping #{relative_path} (Already exists in R2)"
      next
    end

    puts "Uploading #{relative_path} -> #{key} (Type: #{content_type})..."
    File.open(file_path, 'rb') do |file|
      s3.put_object(
        bucket: bucket_name,
        key: key,
        body: file,
        content_type: content_type,
        cache_control: "public, max-age=31536000, immutable"
      )
    end
  end
end

# 3. Clean up the public/assets directory so it doesn't block local development serving
puts "Cleaning up local precompiled assets to keep development serving clean..."
system("bin/rails assets:clobber")

puts "🎉 Success! All precompiled assets and sales flyer files have been compiled and uploaded to your Cloudflare R2 bucket!"
