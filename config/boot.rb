ENV["RAILS_MASTER_KEY"] = "00f49982b4fc45c48f6fdb0e7250d758"
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
