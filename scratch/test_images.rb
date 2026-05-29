require 'nokogiri'
require 'open-uri'

cpn = 'CPN-556573266'
product_id = nil

# 1. Search in manual list files
Dir.glob('db/dom_data/*.html').each do |f|
  doc = Nokogiri::HTML(File.read(f))
  container = doc.css('.prodTileWrap .prodPannel').find { |c| c.css('.prodName.notranslate').text.include?(cpn) }
  if container
    product_id = container.css('input[id$=_productId]').first&.[]('value')
    puts "Found product_id: #{product_id} in #{f}"
    break
  end
end

if product_id.nil?
  puts "Could not find CPN in list files!"
  exit
end

url = "https://atozspecialties.espwebsite.com/ProductDetails/?productID=#{product_id}"
puts "Fetching detail page: #{url}"
detail_html = URI.open(url, 'User-Agent' => 'Mozilla/5.0').read
detail_doc = Nokogiri::HTML(detail_html)

# Let's print out all img elements inside .thumb-list or similar, or all images in the HTML
img_urls = detail_doc.css('img').map { |img| img['src'] || img['data-original'] }.compact.uniq
puts "All img URLs on page:"
img_urls.each { |u| puts "  - #{u}" }

# Let's see the image IDs scan:
image_ids = detail_html.scan(/images\/jpg(?:[otb]|eg)\/\d+\/(\d+)\./).flatten.uniq
puts "Image IDs found by scan: #{image_ids.inspect}"

# Let's reconstruct and test URLs
image_ids.each do |id|
  folder = (id.to_i / 10000) * 10000
  types = ['jpgo', 'jpeg', 'jpgt', 'jpgb']
  types.each do |t|
    test_url = "https://media-asicdn.azureedge.net/images/#{t}/#{folder}/#{id}.jpg"
    begin
      URI.open(test_url, "User-Agent" => "Mozilla/5.0", read_timeout: 4, open_timeout: 4) do |stream|
        puts "  [SUCCESS] Type: #{t} works! URL: #{test_url}"
      end
    rescue => e
      puts "  [FAILED] Type: #{t} failed: #{e.message}"
    end
  end
end
