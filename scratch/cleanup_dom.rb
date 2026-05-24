# frozen_string_literal: true

require 'json'

def cleanup_file(filepath)
  puts "Cleaning up #{filepath}..."
  content = File.read(filepath, encoding: 'utf-8').strip
  
  # Check if it has the JSON block header
  if content.start_with?("Script ran on page")
    lines = content.lines
    
    # Locate where the JSON string starts and ends
    # Line 0: Script ran on page and returned:
    # Line 1: ```json
    # Line 2..-2: "..."
    # Line -1: ```
    json_lines = lines[2..-2] || []
    json_str = json_lines.join
    
    begin
      html = JSON.parse(json_str)
      File.write(filepath, html, encoding: 'utf-8')
      puts "  Successfully unwrapped and cleaned #{filepath}! New size: #{html.length} bytes."
    rescue => e
      puts "  Error parsing JSON for #{filepath}: #{e.message}"
    end
  else
    puts "  File #{filepath} is already a clean HTML file."
  end
end

cleanup_file('db/dom_data/pens_catalog.html')
cleanup_file('db/dom_data/first_pen_detail.html')
