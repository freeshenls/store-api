# scratch/crop_imprints.rb
require 'image_processing/mini_magick'

src_path = "/Users/promote/Desktop/store-api/app/assets/images/arttips/imprint_methods.jpg"
dest_dir = "/Users/promote/Desktop/store-api/app/assets/images/arttips"

# Bounding box config (photo itself is rectangular 216x170)
width = 216
height = 170

cols = [20, 276, 532, 788]
rows = [66, 341, 616]

mapping = {
  [0, 0] => "colorimbue.jpg",
  [0, 1] => "deboss.jpg",
  [0, 2] => "deepetch.jpg",
  [0, 3] => "emboss.jpg",
  [1, 0] => "embroidery.jpg",
  [1, 1] => "foilstamp.jpg",
  [1, 2] => "fullcolor.jpg",
  [1, 3] => "heattransfer.jpg",
  [2, 0] => "laserengraved.jpg",
  [2, 1] => "padprint.jpg",
  [2, 2] => "satinetch.jpg",
  [2, 3] => "screenprint.jpg"
}

mapping.each do |(r, c), filename|
  x = cols[c]
  y = rows[r]
  
  dest_path = File.join(dest_dir, filename)
  puts "Cropping Row #{r}, Col #{c} to #{filename} (x=#{x}, y=#{y}, w=#{width}, h=#{height}). Padding to 216x216 square..."
  
  # Crop and pad using ImageProcessing MiniMagick to prevent browser cropping issues!
  ImageProcessing::MiniMagick
    .source(src_path)
    .crop("#{width}x#{height}+#{x}+#{y}")
    .background("white")
    .gravity("center")
    .extent("216x216")
    .call(destination: dest_path)
end

puts "🎉 Imprint cropping completed successfully! All images padded to perfect 216x216 squares."
