# frozen_string_literal: true

require 'aws-sdk-codepipeline'
require 'aws-sdk-codebuild'
require 'aws-sdk-sts'
require 'open3'
require 'colorize'

module PipelineWatcher
  class AwsCredentialManager
    def initialize(config)
      @config = config
    end

    def create_clients
      client_options = build_client_options

      codepipeline_client = Aws::CodePipeline::Client.new(client_options)
      sts_client = Aws::STS::Client.new(client_options)

      [codepipeline_client, sts_client]
    end

    def create_codebuild_clients
      client_options = build_client_options

      codebuild_client = Aws::CodeBuild::Client.new(client_options)
      sts_client = Aws::STS::Client.new(client_options)

      [codebuild_client, sts_client]
    end

    def create_unified_clients
      client_options = build_client_options

      codepipeline_client = Aws::CodePipeline::Client.new(client_options)
      codebuild_client = Aws::CodeBuild::Client.new(client_options)
      sts_client = Aws::STS::Client.new(client_options)

      [codepipeline_client, codebuild_client, sts_client]
    end

    def detect_aws_cli_config
      config = { detected: false }

      begin
        # Try to get current AWS CLI configuration
        _stdout, _stderr, status = Open3.capture3('aws configure list')

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
            puts 'AWS credentials are invalid or expired. Please run: aws sso login'.colorize(:yellow)
          end
        end
      rescue StandardError => e
        # AWS CLI not available or not configured
        puts "Note: AWS CLI not detected (#{e.message})".colorize(:yellow) if ENV['DEBUG']
      end

      config
    end

    def credentials_valid?(sts_client = nil)
      sts_client ||= Aws::STS::Client.new(build_client_options)

      begin
        sts_client.get_caller_identity
        true
      rescue Aws::Errors::ServiceError => e
        if e.message.include?('token') || e.message.include?('expire') || e.message.include?('credential')
          false
        else
          # Other AWS error, but credentials might be valid
          true
        end
      rescue StandardError
        false
      end
    end

    def credentials_error?(error_message)
      error_message.include?('token') ||
      error_message.include?('expire') ||
      error_message.include?('credential')
    end

    def validate_config(config)
      # Check if using AWS CLI or manual credentials
      if config['use_aws_cli']
        required_keys = %w[aws_region aws_account_id]
      else
        required_keys = %w[aws_access_key_id aws_secret_access_key aws_account_id]
      end

      required_keys.all? { |key| config[key] && !config[key].to_s.empty? }
    end

    private

    def build_client_options
      client_options = { region: @config['aws_region'] || 'us-east-1' }

      if @config['use_aws_cli']
        # Use AWS CLI credentials (profile, environment variables, or instance role)
        client_options[:profile] = @config['aws_profile'] if @config['aws_profile']
      else
        # Use manual credentials
        client_options[:access_key_id] = @config['aws_access_key_id']
        client_options[:secret_access_key] = @config['aws_secret_access_key']
      end

      client_options
    end
  end
end
