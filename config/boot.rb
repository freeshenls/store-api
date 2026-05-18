ENV["RAILS_MASTER_KEY"] = "16965aeeb234cc0e8dca8aaa978f7462"
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
