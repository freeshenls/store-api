# scratch/test_picture_upload.rb
require 'open-uri'

ActiveRecord::Base.transaction do
  url = "https://media-asicdn.azureedge.net/images/jpgt/361480000/361487541.jpg"
  puts "Downloading sample image..."
  
  begin
    file = URI.open(url)
    picture = Alchemy::Picture.new(name: "FIFA World Cup Wristbands")
    picture.image_file.attach(
      io: file,
      filename: "361487541.jpg",
      content_type: "image/jpeg"
    )
    
    if picture.save
      puts "Picture saved successfully!"
      puts "ID: #{picture.id}"
      puts "Name: #{picture.name}"
      puts "image_file_name: #{picture.image_file_name}"
      puts "image_file_width: #{picture.image_file_width}"
      puts "image_file_height: #{picture.image_file_height}"
      puts "image_file_size: #{picture.image_file_size}"
      puts "image_file_format: #{picture.image_file_format}"
    else
      puts "Failed to save picture: #{picture.errors.full_messages.join(', ')}"
    end
  rescue => e
    puts "Error: #{e.message}"
    puts e.backtrace.join("\n")
  end
  
  raise ActiveRecord::Rollback # Rollback so we don't pollute the DB during testing
end
