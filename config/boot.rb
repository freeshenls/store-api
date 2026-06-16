ENV["RAILS_MASTER_KEY"] = "c7d86cb5089a605731097d83c8042214"
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Load .env file if it exists in the root directory
dotenv_path = File.expand_path("../.env", __dir__)
if File.exist?(dotenv_path)
  File.readlines(dotenv_path).each do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")
    
    key, val = line.split("=", 2)
    if key && val
      val = val.strip.sub(/\A['"]/, "").sub(/['"]\z/, "")
      ENV[key.strip] ||= val
    end
  end
end

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
