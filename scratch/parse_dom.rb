# frozen_string_literal: true

require 'json'

html = File.read('db/dom_data/pens_catalog.html', encoding: 'utf-8')
match = html.match(/window\.DC\.catalog\s*=\s*(.*?);<\/script>/m)

if match
  puts "Found match!"
  json_str = match[1]
  
  begin
    # Parse JSON
    data = JSON.parse(json_str)
    puts "Parsed JSON successfully!"
    puts "Main Keys: #{data.keys.inspect}"
    
    # Let's search recursively for where 'Eco Spiral' is in the JSON
    def find_key_containing_val(obj, target, path = [])
      if obj.is_a?(Hash)
        obj.each do |k, v|
          if k.to_s.include?(target) || v.to_s.include?(target)
            puts "Found '#{target}' in key/val at path: #{path.join(' -> ')} -> #{k} (Type: #{v.class})"
            if v.is_a?(Array)
              puts "  Array size: #{v.size}"
              puts "  First element class: #{v.first.class}"
              puts "  First element sample keys: #{v.first.keys.inspect if v.first.is_a?(Hash)}"
            end
          end
          find_key_containing_val(v, target, path + [k])
        end
      elsif obj.is_a?(Array)
        obj.each_with_index do |item, idx|
          find_key_containing_val(item, target, path + [idx.to_s])
        end
      end
    end
    
    find_key_containing_val(data, 'Eco Spiral')
    
  rescue => e
    puts "JSON parse error: #{e.message}"
    puts "Start of JSON snippet: #{json_str[0..300]}"
  end
else
  puts "No window.DC.catalog match found!"
end
