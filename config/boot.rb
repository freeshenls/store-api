ENV["RAILS_MASTER_KEY"] = "f7f64b5f992101509ea6a241cbe76fbf"
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
