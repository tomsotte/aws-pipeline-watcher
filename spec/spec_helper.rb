# frozen_string_literal: true

require 'rspec'
require 'yaml'
require_relative '../lib/pipeline_watcher'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Use color output
  config.color = true

  # Use documentation format
  config.formatter = :documentation

  # Clean up test configuration files after each test
  config.after(:each) do
    test_config_file = File.expand_path('~/.pipeline_watcher_config_test.yml')
    File.delete(test_config_file) if File.exist?(test_config_file)
  end
end
