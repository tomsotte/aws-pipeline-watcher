#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to demonstrate the steady UI improvements
# This simulates pipeline status changes without making actual AWS API calls

require 'ostruct'
require_relative 'lib/pipeline_watcher'
require 'yaml'

class UITestRunner
  def initialize
    @config = {
      'aws_region' => 'us-east-1',
      'aws_account_id' => '123456789012',
      'aws_profile' => 'test',
      'use_aws_cli' => true,
      'pipeline_names' => [
        'web-app-pipeline',
        'api-service-pipeline',
        'database-migration'
      ]
    }

    @test_data = generate_test_data
    @current_cycle = 0
  end

  def run_test
    puts 'AWS Pipeline Watcher - UI Steadiness Test'.colorize(:cyan)
    puts '=' * 50
    puts 'This test demonstrates the improved steady UI that updates in-place'
    puts 'without screen flickering. Watch how only changed data updates.'
    puts
    puts 'Press Ctrl+C to stop the test'
    puts '=' * 50
    puts

    # Create a mock watcher
    watcher = create_mock_watcher

    # Override the get_latest_execution method to return our test data
    watcher.define_singleton_method(:get_latest_execution) do |pipeline_name|
      get_mock_execution_data(pipeline_name)
    end

    watcher.define_singleton_method(:get_current_step_info) do |pipeline_name, execution_id|
      get_mock_step_info(pipeline_name)
    end

    # Start the test monitoring
    watcher.start_watching
  end

  private

  def create_mock_watcher
    # Mock AWS client to avoid actual API calls
    mock_client = Object.new

    # Create watcher instance
    watcher = PipelineWatcher::PipelineStatusWatcher.new(@config)

    # Replace the AWS client with our mock
    watcher.instance_variable_set(:@client, mock_client)

    watcher
  end

  def generate_test_data
    {
      'web-app-pipeline' => [
        { status: 'InProgress', step: 'Source:GitHubSource', duration: 120 },
        { status: 'InProgress', step: 'Build:CodeBuild', duration: 180 },
        { status: 'InProgress', step: 'Deploy:DeployToStaging', duration: 240 },
        { status: 'Succeeded', step: 'Completed', duration: 300 },
        { status: 'InProgress', step: 'Source:GitHubSource', duration: 30 }
      ],
      'api-service-pipeline' => [
        { status: 'Succeeded', step: 'Completed', duration: 450 },
        { status: 'InProgress', step: 'Source:GitHubSource', duration: 45 },
        { status: 'InProgress', step: 'Test:RunUnitTests', duration: 90 },
        { status: 'Failed', step: 'Test:RunUnitTests (FAILED)', duration: 135 },
        { status: 'InProgress', step: 'Source:GitHubSource', duration: 30 }
      ],
      'database-migration' => [
        { status: 'InProgress', step: 'Source:GitHubSource', duration: 60 },
        { status: 'InProgress', step: 'Build:ValidateSchema', duration: 120 },
        { status: 'InProgress', step: 'Deploy:RunMigration', duration: 180 },
        { status: 'Succeeded', step: 'Completed', duration: 240 },
        { status: 'Succeeded', step: 'Completed', duration: 240 }
      ]
    }
  end

  def get_mock_execution_data(pipeline_name)
    data = @test_data[pipeline_name]
    return nil unless data

    cycle_data = data[@current_cycle % data.length]

    # Create a mock execution object
    execution = OpenStruct.new(
      status: cycle_data[:status],
      start_time: Time.now - cycle_data[:duration],
      pipeline_execution_id: "test-#{pipeline_name}-#{@current_cycle}",
      source_revisions: [
        OpenStruct.new(revision_id: generate_mock_revision)
      ]
    )

    # Increment cycle for next refresh (but do it in a way that creates interesting changes)
    if pipeline_name == @config['pipeline_names'].last
      @current_cycle += 1
    end

    execution
  end

  def get_mock_step_info(pipeline_name)
    data = @test_data[pipeline_name]
    return { step: 'Unknown', actual_status: nil } unless data

    cycle_data = data[@current_cycle % data.length]

    # Return the new format with step and actual_status
    case cycle_data[:status]
    when 'InProgress'
      { step: cycle_data[:step], actual_status: 'InProgress' }
    when 'Failed'
      { step: cycle_data[:step], actual_status: 'Failed' }
    when 'Succeeded'
      { step: cycle_data[:step], actual_status: 'Succeeded' }
    else
      { step: cycle_data[:step], actual_status: cycle_data[:status] }
    end
  end

  def generate_mock_revision
    # Generate a realistic-looking commit hash
    chars = ('a'..'f').to_a + ('0'..'9').to_a
    (0...40).map { chars.sample }.join
  end
end

# Handle Ctrl+C gracefully
trap('INT') do
  puts "\n\nUI Test completed!".colorize(:green)
  puts 'Key improvements demonstrated:'.colorize(:yellow)
  puts '• No screen flickering or blinking'
  puts '• Only changed data updates in-place'
  puts '• Cursor positioning for steady display'
  puts '• Smooth transitions between states'
  puts '• Header timestamp updates without full refresh'
  exit
end

# Run the test
if __FILE__ == $0
  puts 'Starting UI Steadiness Test...'
  sleep 1

  test_runner = UITestRunner.new
  test_runner.run_test
end
