# frozen_string_literal: true

require 'thor'
require 'yaml'
require 'fileutils'
require 'open3'
require 'json'
require 'time'
require 'colorize'
require_relative 'aws_credential_manager'
require_relative 'unified_status_watcher'

module PipelineWatcher
  class CLI < Thor
    CONFIG_DIR = File.expand_path('~/.config/pipeline-watcher')
    CONFIG_FILE = File.join(CONFIG_DIR, 'config.yml')
    CREDENTIALS_FILE = File.join(CONFIG_DIR, 'credentials.yml')

    desc 'config', 'Configure AWS credentials, pipeline and CodeBuild project settings'
    def config
      puts 'AWS Pipeline/CodeBuild Watcher Configuration'.colorize(:cyan)
      puts '=' * 40

      current_config = load_config
      credential_manager = AwsCredentialManager.new(current_config)
      aws_cli_config = credential_manager.detect_aws_cli_config

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

      print "CodeBuild project names (comma-separated) [#{(current_config['codebuild_project_names'] || []).join(', ')}]: "
      codebuild_names_input = $stdin.gets.chomp
      codebuild_project_names = if codebuild_names_input.empty?
                                  current_config['codebuild_project_names'] || []
                                else
                                  codebuild_names_input.split(',').map(&:strip)
                                end

      config = {
        'aws_access_key_id' => aws_access_key_id,
        'aws_secret_access_key' => aws_secret_access_key,
        'aws_region' => aws_region,
        'aws_account_id' => aws_account_id,
        'aws_profile' => aws_profile,
        'use_aws_cli' => (aws_access_key_id.nil? && aws_secret_access_key.nil?),
        'pipeline_names' => pipeline_names,
        'codebuild_project_names' => codebuild_project_names
      }

      FileUtils.mkdir_p(CONFIG_DIR) unless Dir.exist?(CONFIG_DIR)
      File.write(CONFIG_FILE, config.to_yaml)
      puts "\nConfiguration saved successfully!".colorize(:green)
      puts "Configured #{pipeline_names.size} pipeline(s) and #{codebuild_project_names.size} CodeBuild project(s) for monitoring.".colorize(:light_black)
      puts "Config location: #{CONFIG_FILE}".colorize(:light_black)
    end

    desc 'watch', 'Watch pipeline and CodeBuild project statuses (default command)'
    default_task :watch
    def watch
      config = load_config

      credential_manager = AwsCredentialManager.new(config)

      unless config_valid?(config, credential_manager)
        puts "Configuration missing or incomplete. Please run 'config' command first.".colorize(:red)
        puts "Make sure to configure at least one pipeline or CodeBuild project to monitor.".colorize(:yellow)
        return
      end

      watcher = UnifiedStatusWatcher.new(config, credential_manager)
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

    def config_valid?(config, credential_manager)
      credential_manager.validate_config(config) &&
        ((config['pipeline_names'] && config['pipeline_names'].is_a?(Array) && !config['pipeline_names'].empty?) ||
         (config['codebuild_project_names'] && config['codebuild_project_names'].is_a?(Array) && !config['codebuild_project_names'].empty?))
    end


  end
end
