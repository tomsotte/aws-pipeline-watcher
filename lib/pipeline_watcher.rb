# frozen_string_literal: true

require 'thor'
require 'yaml'
require 'aws-sdk-codepipeline'
require 'colorize'
require 'time'
require 'json'
require 'open3'
require_relative 'pipeline_watcher/version'

module PipelineWatcher
  class CLI < Thor
    CONFIG_FILE = File.expand_path('~/.pipeline_watcher_config.yml')

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

      File.write(CONFIG_FILE, config.to_yaml)
      puts "\nConfiguration saved successfully!".colorize(:green)
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

      YAML.load_file(CONFIG_FILE) || {}
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
          end
        end
      rescue StandardError => e
        # AWS CLI not available or not configured
        puts "Note: AWS CLI not detected (#{e.message})".colorize(:yellow) if ENV['DEBUG']
      end

      config
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
      @pipeline_states = {}
    end

    def start_watching
      puts "AWS Pipeline Watcher - Monitoring #{@config['pipeline_names'].size} pipeline(s)".colorize(:cyan)
      puts 'Press Ctrl+C to exit'.colorize(:yellow)
      puts '=' * 80

      trap('INT') do
        puts "\nExiting...".colorize(:yellow)
        exit
      end

      loop do
        clear_screen
        display_header
        @config['pipeline_names'].each do |pipeline_name|
          display_pipeline_status(pipeline_name)
        end
        display_footer
        sleep 5
      rescue Aws::Errors::ServiceError => e
        puts "AWS Error: #{e.message}".colorize(:red)
        sleep 10
      rescue StandardError => e
        puts "Error: #{e.message}".colorize(:red)
        sleep 10
      end
    end

    private

    def clear_screen
      system('clear') || system('cls')
    end

    def display_header
      puts "AWS Pipeline Watcher - Last updated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}".colorize(:cyan)
      puts '=' * 80
      puts
    end

    def display_footer
      puts
      puts 'Refreshing in 5 seconds... (Press Ctrl+C to exit)'.colorize(:light_black)
    end

    def display_pipeline_status(pipeline_name)
      pipeline_execution = get_latest_execution(pipeline_name)

      if pipeline_execution
        status = pipeline_execution.status
        started_at = pipeline_execution.start_time
        source_revision = get_source_revision(pipeline_execution)

        # Get current step info
        current_step_info = get_current_step_info(pipeline_name, pipeline_execution.pipeline_execution_id)

        # Calculate timer
        timer = calculate_timer(started_at, status)

        display_pipeline_line(pipeline_name, status, source_revision, started_at, current_step_info, timer)
      else
        puts "• #{pipeline_name.ljust(25)} | No executions found".colorize(:light_black)
      end
    rescue StandardError => e
      puts "• #{pipeline_name.ljust(25)} | Error: #{e.message}".colorize(:red)
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
        "#{running_action.stage_name}:#{running_action.action_name}"
      elsif failed_action
        "#{failed_action.stage_name}:#{failed_action.action_name} (FAILED)"
      else
        'Completed'
      end
    rescue StandardError
      'Unknown'
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

    def display_pipeline_line(name, status, revision, started_at, step_info, timer)
      status_color = case status
                     when 'Succeeded' then :green
                     when 'Failed' then :red
                     when 'InProgress' then :yellow
                     when 'Stopped' then :light_red
                     else :white
                     end

      started_str = started_at ? started_at.strftime('%m/%d %H:%M') : 'N/A'

      puts "• #{name.ljust(25)} | #{status.colorize(status_color).ljust(20)} | #{revision.ljust(10)} | #{started_str.ljust(12)}"
      puts "  #{step_info.ljust(40)} | #{timer}".colorize(:light_black)
      puts
    end
  end
end
