# scratch/inspect_kv.rb
require 'nokogiri'

html = File.read("tmp/test_detail.html")
doc = Nokogiri::HTML(html)

containers = doc.css('.attributesContainer')

def extract_section_kv(container)
  kv = {}
  
  # Work on a duplicate of the container to avoid modifying the original doc
  dup_container = container.dup
  
  # 1. Look for criteriaSetBox elements
  dup_container.css('.criteriaSetBox, .dataFieldBlock').each do |box|
    h5 = box.at_css('h5')
    next unless h5
    
    label = h5.text.strip.gsub(/:$/, '').strip
    h5.remove # Remove the label from this box element
    
    # Get the rest of the text as the value
    value = box.text.strip.gsub(/\s+/, ' ').strip
    next if label.empty? || value.empty?
    
    # We want to skip nested duplicate values if they exist, keeping the shortest clean path
    kv[label] = value unless kv.key?(label)
  end
  
  kv
end

containers.each_with_index do |container, index|
  # Try to find header title
  title_el = container.at_css('h4, .hdrTitle, span, div')
  title = title_el ? title_el.text.strip : "Container #{index + 1}"
  
  kv = extract_section_kv(container)
  puts "=================================================="
  puts "SECTION: #{title} (Index: #{index})"
  puts "=================================================="
  kv.each do |k, v|
    puts "  #{k} => #{v}"
  end
end
