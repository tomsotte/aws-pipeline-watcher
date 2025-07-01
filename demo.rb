#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script for AWS Pipeline Watcher
# This script demonstrates the functionality without requiring real AWS credentials

require_relative 'lib/pipeline_watcher'
require 'yaml'

puts 'AWS Pipeline Watcher - Demo Mode'.colorize(:cyan)
puts '=' * 50
puts

# Create a demo configuration
demo_config = {
  'aws_access_key_id' => 'DEMO_ACCESS_KEY',
  'aws_secret_access_key' => 'DEMO_SECRET_KEY',
  'aws_region' => 'us-east-1',
  'aws_account_id' => '123456789012',
  'pipeline_names' => [
    'web-app-pipeline',
    'api-service-pipeline',
    'database-migration',
    'frontend-deployment'
  ]
}

puts 'Demo Configuration Options:'.colorize(:yellow)
puts
puts '1. AWS CLI Integration (Recommended):'.colorize(:green)
puts '   ✓ Auto-detects AWS credentials from your CLI configuration'
puts '   ✓ Automatically gets your AWS Account ID and Region'
puts '   ✓ Supports AWS profiles for multiple accounts'
puts '   ✓ More secure than storing access keys'
puts
puts '2. Manual Credentials:'.colorize(:cyan)
puts '   • Manually enter AWS Access Key ID and Secret'
puts '   • Specify AWS Region and Account ID'
puts '   • Credentials stored in config file'
puts
puts "Sample AWS Region: #{demo_config['aws_region']}"
puts "Sample AWS Account ID: #{demo_config['aws_account_id']}"
puts "Sample Pipelines: #{demo_config['pipeline_names'].join(', ')}"
puts

# Demonstrate CLI help
puts 'Available CLI Commands:'.colorize(:green)
puts '=' * 30
puts '• pipeline-watcher config  - Configure AWS credentials and pipelines'
puts '• pipeline-watcher watch   - Start monitoring pipelines (default)'
puts '• pipeline-watcher help    - Show help information'
puts

# Demonstrate configuration validation
puts 'Configuration Validation:'.colorize(:green)
puts '=' * 30
cli = PipelineWatcher::CLI.new

valid_config = {
  'aws_access_key_id' => 'test_key',
  'aws_secret_access_key' => 'test_secret',
  'aws_account_id' => '123456789012',
  'pipeline_names' => ['test-pipeline']
}

invalid_config = {
  'aws_access_key_id' => 'test_key',
  'pipeline_names' => []
}

puts "Valid config check: #{cli.send(:config_valid?, valid_config) ? 'PASS'.colorize(:green) : 'FAIL'.colorize(:red)}"
puts "Invalid config check: #{cli.send(:config_valid?, invalid_config) ? 'PASS'.colorize(:green) : 'FAIL'.colorize(:red)}"
puts

# Demonstrate formatting functions
puts 'Time Formatting Examples:'.colorize(:green)
puts '=' * 30

# Demonstrate time formatting without creating actual watcher
class DemoWatcher
  def format_duration(seconds)
    hours = (seconds / 3600).to_i
    minutes = ((seconds % 3600) / 60).to_i
    secs = (seconds % 60).to_i

    if hours.positive?
      "#{hours}h #{minutes}m #{secs}s"
    elsif minutes.positive?
      "#{minutes}m #{secs}s"
    else
      "#{secs}s"
    end
  end
end

demo_watcher = DemoWatcher.new
durations = [45, 125, 3665, 7325]
durations.each do |duration|
  formatted = demo_watcher.format_duration(duration)
  puts "#{duration} seconds → #{formatted}"
end
puts

# Demonstrate sample pipeline status display
puts 'Sample Pipeline Status Display:'.colorize(:green)
puts '=' * 50
puts "AWS Pipeline Watcher - Last updated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}".colorize(:cyan)
puts '=' * 80
puts

# Mock pipeline data
pipelines = [
  {
    name: 'web-app-pipeline',
    status: 'InProgress',
    revision: 'abc12345',
    started: '01/15 14:25',
    step: 'Deploy:DeployToStaging',
    timer: '5m 23s (running)',
    color: :yellow
  },
  {
    name: 'api-service-pipeline',
    status: 'Succeeded',
    revision: 'def67890',
    started: '01/15 13:45',
    step: 'Completed',
    timer: '12m 34s (completed)',
    color: :green
  },
  {
    name: 'database-migration',
    status: 'Failed',
    revision: 'ghi11111',
    started: '01/15 14:20',
    step: 'Test:RunIntegrationTests (FAILED)',
    timer: '10m 15s (completed)',
    color: :red
  },
  {
    name: 'frontend-deployment',
    status: 'Stopped',
    revision: 'jkl22222',
    started: '01/15 12:10',
    step: 'Build:CompileAssets',
    timer: '2h 15m 45s (completed)',
    color: :light_red
  }
]

pipelines.each do |pipeline|
  puts "• #{pipeline[:name].ljust(25)} | #{pipeline[:status].colorize(pipeline[:color]).ljust(20)} | #{pipeline[:revision].ljust(10)} | #{pipeline[:started].ljust(12)}"
  puts "  #{pipeline[:step].ljust(40)} | #{pipeline[:timer]}".colorize(:light_black)
  puts
end

puts 'Refreshing in 5 seconds... (Press Ctrl+C to exit)'.colorize(:light_black)
puts

puts 'Demo Features:'.colorize(:yellow)
puts '=' * 20
puts '✓ Real-time monitoring (updates every 5 seconds)'
puts '✓ Color-coded status indicators'
puts '✓ Detailed execution information'
puts '✓ Multiple pipeline support'
puts '✓ Easy configuration management'
puts '✓ Timer tracking for execution duration'
puts '✓ Current step identification'
puts '✓ Steady UI - No screen flickering or blinking!'
puts '✓ In-place updates - Only changed data refreshes'
puts '✓ Smooth cursor positioning for better UX'
puts

puts 'Getting Started:'.colorize(:yellow)
puts '=' * 20
puts '1. Run: ./bin/pipeline-watcher config'
puts '2. Enter your AWS credentials and pipeline names'
puts '3. Run: ./bin/pipeline-watcher'
puts '4. Monitor your pipelines in real-time!'
puts

puts 'Requirements:'.colorize(:yellow)
puts '=' * 15
puts '• Ruby 3.0.0 or higher'
puts '• AWS account with CodePipeline access'
puts '• AWS credentials (Access Key ID and Secret)'
puts '• Pipeline names you want to monitor'
puts

puts 'AWS Permissions Needed:'.colorize(:yellow)
puts '=' * 25
puts '• codepipeline:ListPipelines'
puts '• codepipeline:ListPipelineExecutions'
puts '• codepipeline:ListActionExecutions'
puts '• codepipeline:GetPipeline'
puts

puts 'Demo completed! Ready to monitor your AWS CodePipelines.'.colorize(:green)
