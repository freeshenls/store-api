ENV["RAILS_MASTER_KEY"] = "2b3178fd3b0a602db78cd73342fd54a2"
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
