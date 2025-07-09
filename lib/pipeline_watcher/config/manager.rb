# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module PipelineWatcher
  module Config
    # Simple configuration manager that handles loading, saving, and validating config
    class Manager
      CONFIG_DIR = File.expand_path('~/.config/aws-pipeline-watcher')
      CONFIG_FILE = File.join(CONFIG_DIR, 'config.yml')

      attr_reader :config

      def initialize
        @config = load_config
      end

      # Load configuration from file or return default
      def load_config
        return default_config unless File.exist?(CONFIG_FILE)

        YAML.load_file(CONFIG_FILE) || default_config
      rescue StandardError => e
        puts "Warning: Could not load config file (#{e.message}). Using defaults."
        default_config
      end

      # Save current configuration to file
      def save_config
        ensure_config_dir_exists
        File.write(CONFIG_FILE, @config.to_yaml)
      rescue StandardError => e
        puts "Error: Could not save config file (#{e.message})"
        false
      end

      # Update configuration with new values
      def update(new_config)
        @config.merge!(new_config)
        save_config
      end

      # Get a configuration value with optional default
      def get(key, default = nil)
        @config[key] || default
      end

      # Set a configuration value
      def set(key, value)
        @config[key] = value
      end

      # Check if configuration is valid for monitoring
      def valid?
        has_aws_credentials? && has_items_to_monitor?
      end

      # Get list of validation errors
      def validation_errors
        errors = []
        errors << "Missing AWS credentials" unless has_aws_credentials?
        errors << "No pipelines or builds configured" unless has_items_to_monitor?
        errors
      end

      # Check if using AWS CLI or manual credentials
      def using_aws_cli?
        @config['use_aws_cli'] == true
      end

      # Get pipeline names to monitor
      def pipeline_names
        @config['pipeline_names'] || []
      end

      # Get CodeBuild project names to monitor
      def build_project_names
        @config['codebuild_project_names'] || []
      end

      # Get AWS region
      def aws_region
        @config['aws_region'] || 'us-east-1'
      end

      # Get AWS profile (for CLI mode)
      def aws_profile
        @config['aws_profile'] || 'default'
      end

      # Get AWS account ID
      def aws_account_id
        @config['aws_account_id']
      end

      # Display current configuration summary
      def summary
        summary = []
        summary << "Configuration Summary:"
        summary << "  AWS Mode: #{using_aws_cli? ? 'CLI' : 'Manual credentials'}"
        summary << "  Region: #{aws_region}"
        summary << "  Profile: #{aws_profile}" if using_aws_cli?
        summary << "  Account ID: #{aws_account_id || 'Not set'}"
        summary << "  Pipelines: #{pipeline_names.join(', ')}" unless pipeline_names.empty?
        summary << "  Builds: #{build_project_names.join(', ')}" unless build_project_names.empty?
        summary.join("\n")
      end

      private

      # Default configuration structure
      def default_config
        {
          'use_aws_cli' => true,
          'aws_region' => 'us-east-1',
          'aws_profile' => 'default',
          'pipeline_names' => [],
          'codebuild_project_names' => []
        }
      end

      # Check if AWS credentials are configured
      def has_aws_credentials?
        if using_aws_cli?
          # For CLI mode, we need region and account_id
          !!((@config['aws_region'] && !@config['aws_region'].empty?) &&
             (@config['aws_account_id'] && !@config['aws_account_id'].empty?))
        else
          # For manual mode, we need access key, secret key, region, and account_id
          !!((@config['aws_access_key_id'] && !@config['aws_access_key_id'].empty?) &&
             (@config['aws_secret_access_key'] && !@config['aws_secret_access_key'].empty?) &&
             (@config['aws_region'] && !@config['aws_region'].empty?) &&
             (@config['aws_account_id'] && !@config['aws_account_id'].empty?))
        end
      end

      # Check if there are items to monitor
      def has_items_to_monitor?
        !!((pipeline_names && !pipeline_names.empty?) ||
           (build_project_names && !build_project_names.empty?))
      end

      # Ensure configuration directory exists
      def ensure_config_dir_exists
        FileUtils.mkdir_p(CONFIG_DIR) unless Dir.exist?(CONFIG_DIR)
      end
    end
  end
end
