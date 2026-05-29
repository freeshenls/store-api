# scratch/inspect_attributes.rb
require 'nokogiri'

html = File.read("tmp/test_detail.html")
doc = Nokogiri::HTML(html)

containers = doc.css('.attributesContainer')
detail_container = containers[1]
if detail_container
  box = detail_container.at_css('.criteriaSetBox')
  if box
    puts "BOX HTML:"
    puts box.to_html
  else
    puts "No criteriaSetBox found!"
  end
end
