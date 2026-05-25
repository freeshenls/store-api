ENV["RAILS_MASTER_KEY"] = "ff197f5086524b2ac992b96dec5b0227"
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
