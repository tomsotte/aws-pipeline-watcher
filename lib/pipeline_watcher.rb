# frozen_string_literal: true

require 'thor'
require 'yaml'
require 'aws-sdk-codepipeline'
require 'aws-sdk-sts'
require 'aws-sdk-sso'
require 'aws-sdk-ssooidc'
require 'colorize'
require 'time'
require 'json'
require 'open3'
require 'fileutils'
require_relative 'pipeline_watcher/version'

module PipelineWatcher
  class CLI < Thor
    CONFIG_DIR = File.expand_path('~/.config/pipeline-watcher')
    CONFIG_FILE = File.join(CONFIG_DIR, 'config.yml')
    CREDENTIALS_FILE = File.join(CONFIG_DIR, 'credentials.yml')

    desc 'config', 'Configure AWS credentials and pipeline settings'
    def config
      puts 'AWS Pipeline Watcher Configuration'.colorize(:cyan)
      puts '=' * 40

      current_config = load_config
      aws_cli_config = detect_aws_cli_config

      # Show detected AWS CLI information
      if aws_cli_config[:detected]
        puts
        puts 'Detected AWS CLI Configuration:'.colorize(:green)
        puts "  Region: #{aws_cli_config[:region]}" if aws_cli_config[:region]
        puts "  Account ID: #{aws_cli_config[:account_id]}" if aws_cli_config[:account_id]
        puts "  Profile: #{aws_cli_config[:profile]}" if aws_cli_config[:profile]
        puts
      end

      print "Use AWS CLI credentials? [#{aws_cli_config[:detected] ? 'Y/n' : 'y/N'}]: "
      use_aws_cli = $stdin.gets.chomp.downcase
      use_aws_cli = aws_cli_config[:detected] ? 'y' : 'n' if use_aws_cli.empty?

      if use_aws_cli == 'y' && aws_cli_config[:detected]
        aws_access_key_id = nil # Will use AWS CLI credentials
        aws_secret_access_key = nil # Will use AWS CLI credentials
        aws_region = aws_cli_config[:region]
        aws_account_id = aws_cli_config[:account_id]
        aws_profile = aws_cli_config[:profile]

        puts 'Using AWS CLI credentials'.colorize(:green)
      else
        print "AWS Access Key ID [#{current_config['aws_access_key_id'] || 'not set'}]: "
        aws_access_key_id = $stdin.gets.chomp
        aws_access_key_id = current_config['aws_access_key_id'] if aws_access_key_id.empty?

        print "AWS Secret Access Key [#{current_config['aws_secret_access_key'] ? '***hidden***' : 'not set'}]: "
        aws_secret_access_key = $stdin.gets.chomp
        aws_secret_access_key = current_config['aws_secret_access_key'] if aws_secret_access_key.empty?

        print "AWS Region [#{current_config['aws_region'] || aws_cli_config[:region] || 'us-east-1'}]: "
        aws_region = $stdin.gets.chomp
        aws_region = current_config['aws_region'] || aws_cli_config[:region] || 'us-east-1' if aws_region.empty?

        print "AWS Account ID [#{current_config['aws_account_id'] || aws_cli_config[:account_id] || 'not set'}]: "
        aws_account_id = $stdin.gets.chomp
        aws_account_id = current_config['aws_account_id'] || aws_cli_config[:account_id] if aws_account_id.empty?

        aws_profile = nil
      end

      print "Pipeline names (comma-separated) [#{(current_config['pipeline_names'] || []).join(', ')}]: "
      pipeline_names_input = $stdin.gets.chomp
      pipeline_names = if pipeline_names_input.empty?
                         current_config['pipeline_names'] || []
                       else
                         pipeline_names_input.split(',').map(&:strip)
                       end

      config = {
        'aws_access_key_id' => aws_access_key_id,
        'aws_secret_access_key' => aws_secret_access_key,
        'aws_region' => aws_region,
        'aws_account_id' => aws_account_id,
        'aws_profile' => aws_profile,
        'use_aws_cli' => (aws_access_key_id.nil? && aws_secret_access_key.nil?),
        'pipeline_names' => pipeline_names
      }

      FileUtils.mkdir_p(CONFIG_DIR) unless Dir.exist?(CONFIG_DIR)
      File.write(CONFIG_FILE, config.to_yaml)
      puts "\nConfiguration saved successfully!".colorize(:green)
      puts "Config location: #{CONFIG_FILE}".colorize(:light_black)
    end

    desc 'watch', 'Watch pipeline statuses (default command)'
    default_task :watch
    def watch
      config = load_config

      unless config_valid?(config)
        puts "Configuration missing or incomplete. Please run 'config' command first.".colorize(:red)
        return
      end

      watcher = PipelineStatusWatcher.new(config)
      watcher.start_watching
    end

    private

    def load_config
      return {} unless File.exist?(CONFIG_FILE)

      config = YAML.load_file(CONFIG_FILE) || {}

      # Load and merge credentials if they exist
      if File.exist?(CREDENTIALS_FILE)
        credentials = YAML.load_file(CREDENTIALS_FILE) || {}
        config.merge!(credentials)
      end

      config
    rescue StandardError
      {}
    end

    def config_valid?(config)
      # Check if using AWS CLI or manual credentials
      if config['use_aws_cli']
        required_keys = %w[aws_region aws_account_id pipeline_names]
      else
        required_keys = %w[aws_access_key_id aws_secret_access_key aws_account_id pipeline_names]
      end

      required_keys.all? { |key| config[key] && !config[key].to_s.empty? } &&
        config['pipeline_names'].is_a?(Array) && !config['pipeline_names'].empty?
    end

    def detect_aws_cli_config
      config = { detected: false }

      begin
        # Try to get current AWS CLI configuration
        stdout, stderr, status = Open3.capture3('aws configure list')

        if status.success?
          # Get region
          region_output, = Open3.capture3('aws configure get region')
          config[:region] = region_output.strip unless region_output.strip.empty?

          # Get profile
          profile_output, = Open3.capture3('aws configure get profile')
          config[:profile] = profile_output.strip unless profile_output.strip.empty?
          config[:profile] = 'default' if config[:profile].nil? || config[:profile].empty?

          # Try to get account ID using STS
          sts_output, sts_stderr, sts_status = Open3.capture3('aws sts get-caller-identity --query Account --output text')
          if sts_status.success?
            config[:account_id] = sts_output.strip
            config[:detected] = true
          elsif sts_stderr.include?('token') || sts_stderr.include?('expire')
            # Token might be expired, try to refresh
            puts 'AWS credentials may be expired, attempting refresh...'.colorize(:yellow)
            if refresh_aws_credentials(config[:profile])
              # Retry getting account ID
              sts_output, sts_stderr, sts_status = Open3.capture3('aws sts get-caller-identity --query Account --output text')
              if sts_status.success?
                config[:account_id] = sts_output.strip
                config[:detected] = true
              end
            end
          end
        end
      rescue StandardError => e
        # AWS CLI not available or not configured
        puts "Note: AWS CLI not detected (#{e.message})".colorize(:yellow) if ENV['DEBUG']
      end

      config
    end

    def refresh_aws_credentials(profile = 'default')
      begin
        puts 'Attempting to refresh AWS SSO credentials...'.colorize(:cyan)

        # Try AWS SSO login
        login_output, login_stderr, login_status = Open3.capture3("aws sso login --profile #{profile}")

        if login_status.success?
          puts 'AWS SSO credentials refreshed successfully!'.colorize(:green)

          # Save token information if available
          save_refreshed_credentials(profile)
          return true
        else
          puts "SSO login failed: #{login_stderr}".colorize(:red)
          return false
        end
      rescue StandardError => e
        puts "Error refreshing credentials: #{e.message}".colorize(:red)
        return false
      end
    end

    def save_refreshed_credentials(profile)
      begin
        # Try to get the current credentials and save them
        aws_dir = File.expand_path('~/.aws')
        credentials_cache_dir = File.join(aws_dir, 'sso', 'cache')

        if Dir.exist?(credentials_cache_dir)
          # Find the most recent cache file
          cache_files = Dir.glob(File.join(credentials_cache_dir, '*.json'))
          if !cache_files.empty?
            latest_cache = cache_files.max_by { |f| File.mtime(f) }
            cache_data = JSON.parse(File.read(latest_cache))

            if cache_data['accessToken'] && cache_data['expiresAt']
              # Save token info to our credentials file
              FileUtils.mkdir_p(CONFIG_DIR) unless Dir.exist?(CONFIG_DIR)

              credentials = {
                'sso_access_token' => cache_data['accessToken'],
                'sso_expires_at' => cache_data['expiresAt'],
                'last_refreshed' => Time.now.iso8601
              }

              File.write(CREDENTIALS_FILE, credentials.to_yaml)
              puts "Credentials cached locally".colorize(:light_black)
            end
          end
        end
      rescue StandardError => e
        # Don't fail if we can't save credentials, just log
        puts "Note: Could not cache credentials locally (#{e.message})".colorize(:light_black) if ENV['DEBUG']
      end
    end
  end

  class PipelineStatusWatcher
    def initialize(config)
      @config = config

      # Configure AWS client based on whether using AWS CLI or manual credentials
      client_options = { region: config['aws_region'] || 'us-east-1' }

      if config['use_aws_cli']
        # Use AWS CLI credentials (profile, environment variables, or instance role)
        client_options[:profile] = config['aws_profile'] if config['aws_profile']
      else
        # Use manual credentials
        client_options[:access_key_id] = config['aws_access_key_id']
        client_options[:secret_access_key] = config['aws_secret_access_key']
      end

      @client = Aws::CodePipeline::Client.new(client_options)
      @sts_client = Aws::STS::Client.new(client_options)
      @pipeline_states = {}
      @last_token_check = Time.now
    end

    def start_watching
      @first_run = true
      @pipeline_data = {}

      puts "AWS Pipeline Watcher - Monitoring #{@config['pipeline_names'].size} pipeline(s)".colorize(:cyan)
      puts 'Press Ctrl+C to exit'.colorize(:yellow)
      puts '=' * 80

      trap('INT') do
        show_cursor
        puts "\nExiting...".colorize(:yellow)
        exit
      end

      # Hide cursor to prevent flickering
      hide_cursor

      loop do
        begin
          # Check if we need to refresh credentials (every 30 minutes)
          if Time.now - @last_token_check > 1800 && @config['use_aws_cli']
            check_and_refresh_credentials
            @last_token_check = Time.now
          end

          if @first_run
            display_initial_screen
            @first_run = false
          else
            update_display_in_place
          end
          sleep 5
        rescue Aws::Errors::ServiceError => e
          if e.message.include?('token') || e.message.include?('expire') || e.message.include?('credential')
            display_error("AWS credentials may be expired, attempting refresh...")
            if @config['use_aws_cli'] && refresh_aws_credentials_runtime
              display_error("Credentials refreshed, retrying...")
              sleep 2
            else
              display_error("AWS Error: #{e.message}")
              sleep 10
            end
          else
            display_error("AWS Error: #{e.message}")
            sleep 10
          end
        rescue StandardError => e
          display_error("Error: #{e.message}")
          sleep 10
        end
      end
    ensure
      show_cursor
    end

    private

    def hide_cursor
      print "\e[?25l"
    end

    def show_cursor
      print "\e[?25h"
    end

    def move_cursor_to(row, col)
      print "\e[#{row};#{col}H"
    end

    def clear_line
      print "\e[K"
    end

    def save_cursor_position
      print "\e[s"
    end

    def restore_cursor_position
      print "\e[u"
    end

    def display_initial_screen
      # Clear screen once and set up the static layout
      system('clear') || system('cls')

      # Display header
      puts "AWS Pipeline Watcher - Last updated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}".colorize(:cyan)
      puts '=' * 80
      puts

      # Reserve space for each pipeline (6 lines per pipeline: status, details, error1, error2, error3, spacing)
      @config['pipeline_names'].each_with_index do |pipeline_name, index|
        @pipeline_data[pipeline_name] = { row: 4 + (index * 6), last_display: '' }
        puts # Pipeline status line
        puts # Pipeline details line
        puts # Error line 1 (if needed)
        puts # Error line 2 (if needed)
        puts # Error line 3 (if needed)
        puts # Empty spacing line
      end

      puts
      puts 'Refreshing in 5 seconds... (Press Ctrl+C to exit)'.colorize(:light_black)

      # Now populate with actual data
      @config['pipeline_names'].each do |pipeline_name|
        update_pipeline_display(pipeline_name)
      end

      # Update header timestamp
      update_header_timestamp
    end

    def update_display_in_place
      # Update timestamp in header
      update_header_timestamp

      # Update each pipeline's display
      @config['pipeline_names'].each do |pipeline_name|
        update_pipeline_display(pipeline_name)
      end
    end

    def update_header_timestamp
      move_cursor_to(1, 1)
      clear_line
      print "AWS Pipeline Watcher - Last updated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}".colorize(:cyan)
    end

    def display_error(message)
      # Display error at the bottom without disrupting the main display
      save_cursor_position
      move_cursor_to(@config['pipeline_names'].size * 6 + 6, 1)
      clear_line
      print message.colorize(:red)
      restore_cursor_position
    end

    def update_pipeline_display(pipeline_name)
      begin
        pipeline_execution = get_latest_execution(pipeline_name)

        if pipeline_execution
          status = pipeline_execution.status
          started_at = pipeline_execution.start_time
          source_revision = get_source_revision(pipeline_execution)

          # Get current step info and actual status
          step_info = get_current_step_info(pipeline_name, pipeline_execution.pipeline_execution_id)

          # Use the actual status from step analysis if it's more accurate than execution status
          actual_status = step_info[:actual_status] || status

          # If execution says InProgress but steps show Completed, trust the steps
          if status == 'InProgress' && step_info[:step] == 'Completed'
            actual_status = 'Succeeded'
          end

          # Calculate timer
          timer = calculate_timer(started_at, actual_status)

          new_display = format_pipeline_display(pipeline_name, actual_status, source_revision, started_at, step_info[:step], timer, step_info[:error_details])
        else
          new_display = format_no_execution_display(pipeline_name)
        end

        # Only update if the display has changed
        pipeline_info = @pipeline_data[pipeline_name]
        if pipeline_info[:last_display] != new_display
          update_pipeline_lines(pipeline_name, new_display)
          pipeline_info[:last_display] = new_display
        end
      rescue StandardError => e
        error_display = format_error_display(pipeline_name, e.message)
        pipeline_info = @pipeline_data[pipeline_name]
        if pipeline_info[:last_display] != error_display
          update_pipeline_lines(pipeline_name, error_display)
          pipeline_info[:last_display] = error_display
        end
      end
    end

    def format_pipeline_display(name, status, revision, started_at, step_info, timer, error_details = nil)
      status_color = case status
                    when 'Succeeded' then :green
                    when 'Failed' then :red
                    when 'InProgress' then :yellow
                    when 'Stopped' then :light_red
                    else :white
                    end

      started_str = started_at ? started_at.strftime('%m/%d %H:%M') : 'N/A'

      line1 = "• #{name.ljust(25)} | #{status.colorize(status_color).ljust(20)} | #{revision.ljust(10)} | #{started_str.ljust(12)}"
      line2 = "  #{step_info.ljust(40)} | #{timer}".colorize(:light_black)

      # Add error details for failed pipelines
      lines = { line1: line1, line2: line2 }

      if status == 'Failed' && error_details && !error_details.empty?
        lines[:error_lines] = error_details.map { |detail| "    ⚠️  #{detail}".colorize(:red) }
      end

      lines
    end

    def format_no_execution_display(pipeline_name)
      line1 = "• #{pipeline_name.ljust(25)} | No executions found".colorize(:light_black)
      line2 = "  N/A".colorize(:light_black)

      { line1: line1, line2: line2 }
    end

    def format_error_display(pipeline_name, error_message)
      line1 = "• #{pipeline_name.ljust(25)} | Error: #{error_message}".colorize(:red)
      line2 = "  Connection issue".colorize(:light_black)

      { line1: line1, line2: line2 }
    end

    def update_pipeline_lines(pipeline_name, display_data)
      pipeline_info = @pipeline_data[pipeline_name]
      row = pipeline_info[:row]

      # Update first line (pipeline status)
      move_cursor_to(row, 1)
      clear_line
      print display_data[:line1]

      # Update second line (step info)
      move_cursor_to(row + 1, 1)
      clear_line
      print display_data[:line2]

      # Update error details if present (for failed pipelines)
      if display_data[:error_lines]
        display_data[:error_lines].each_with_index do |error_line, index|
          move_cursor_to(row + 2 + index, 1)
          clear_line
          print error_line
        end

        # Clear any remaining error lines from previous display
        (display_data[:error_lines].size..2).each do |index|
          move_cursor_to(row + 2 + index, 1)
          clear_line
        end
      else
        # Clear any previous error lines if pipeline is no longer failed
        (0..2).each do |index|
          move_cursor_to(row + 2 + index, 1)
          clear_line
        end
      end
    end

    def get_latest_execution(pipeline_name)
      response = @client.list_pipeline_executions({
                                                    pipeline_name: pipeline_name,
                                                    max_results: 1
                                                  })

      response.pipeline_execution_summaries.first
    end

    def get_source_revision(execution)
      if execution.source_revisions && !execution.source_revisions.empty?
        revision = execution.source_revisions.first.revision_id
        revision.length > 8 ? revision[0..7] : revision
      else
        'N/A'
      end
    end

    def get_current_step_info(pipeline_name, execution_id)
      response = @client.list_action_executions({
                                                  pipeline_name: pipeline_name,
                                                  filter: {
                                                    pipeline_execution_id: execution_id
                                                  }
                                                })

      # Find the currently running or most recent failed action
      running_action = response.action_execution_details.find { |action| action.status == 'InProgress' }
      failed_action = response.action_execution_details.find { |action| action.status == 'Failed' }

      if running_action
        { step: "#{running_action.stage_name}:#{running_action.action_name}", actual_status: 'InProgress', error_details: nil }
      elsif failed_action
        error_details = get_failure_details(failed_action)
        { step: "#{failed_action.stage_name}:#{failed_action.action_name} (FAILED)", actual_status: 'Failed', error_details: error_details }
      else
        { step: 'Completed', actual_status: 'Succeeded', error_details: nil }
      end
    rescue StandardError
      { step: 'Unknown', actual_status: nil, error_details: nil }
    end

    def check_and_refresh_credentials
      begin
        # Quick test to see if credentials are still valid
        @sts_client.get_caller_identity
      rescue Aws::Errors::ServiceError => e
        if e.message.include?('token') || e.message.include?('expire') || e.message.include?('credential')
          puts 'Credentials expired, refreshing...'.colorize(:yellow)
          refresh_aws_credentials_runtime
        end
      end
    end

    def refresh_aws_credentials_runtime
      begin
        profile = @config['aws_profile'] || 'default'

        # Try AWS SSO login
        login_output, login_stderr, login_status = Open3.capture3("aws sso login --profile #{profile}")

        if login_status.success?
          # Recreate the clients with refreshed credentials
          client_options = { region: @config['aws_region'] || 'us-east-1' }
          client_options[:profile] = profile

          @client = Aws::CodePipeline::Client.new(client_options)
          @sts_client = Aws::STS::Client.new(client_options)

          puts 'AWS credentials refreshed successfully!'.colorize(:green)
          return true
        else
          puts "Failed to refresh credentials: #{login_stderr}".colorize(:red)
          return false
        end
      rescue StandardError => e
        puts "Error during credential refresh: #{e.message}".colorize(:red)
        return false
      end
    end

    def get_failure_details(failed_action)
      details = []

      # Get error message from action execution
      if failed_action.error_details && failed_action.error_details.message
        error_msg = failed_action.error_details.message
        # Truncate long error messages
        error_msg = error_msg[0..120] + '...' if error_msg.length > 120
        details << "Error: #{error_msg}"
      end

      # Get failure summary if available
      if failed_action.output && failed_action.output.execution_result
        result = failed_action.output.execution_result
        if result.external_execution_summary
          summary = result.external_execution_summary
          summary = summary[0..80] + '...' if summary.length > 80
          details << "Summary: #{summary}"
        end
      end

      # If no specific error details, provide generic info
      if details.empty?
        details << "Action failed in #{failed_action.stage_name} stage"
        details << "Check AWS Console for detailed error information"
      end

      # Limit to 2-3 lines as requested
      details[0..2]
    rescue StandardError
      ["Failed action details unavailable"]
    end

    def calculate_timer(started_at, status)
      return 'N/A' unless started_at

      duration = Time.now - started_at

      case status
      when 'InProgress'
        "#{format_duration(duration)} (running)"
      when 'Succeeded', 'Failed', 'Stopped'
        "#{format_duration(duration)} (completed)"
      else
        format_duration(duration)
      end
    end

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
end
