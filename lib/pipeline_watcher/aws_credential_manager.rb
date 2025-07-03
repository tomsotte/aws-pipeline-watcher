# frozen_string_literal: true

require 'aws-sdk-codepipeline'
require 'aws-sdk-codebuild'
require 'aws-sdk-sts'
require 'open3'
require 'yaml'
require 'json'
require 'time'
require 'fileutils'
require 'colorize'

module PipelineWatcher
  class AwsCredentialManager
    CONFIG_DIR = File.expand_path('~/.config/pipeline-watcher')
    CREDENTIALS_FILE = File.join(CONFIG_DIR, 'credentials.yml')

    def initialize(config)
      @config = config
      @last_token_check = Time.now
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
            # Token might be expired, try to refresh
            puts 'AWS credentials may be expired, attempting refresh...'.colorize(:yellow)
            if refresh_aws_credentials(config[:profile])
              # Retry getting account ID
              sts_output, _sts_stderr, sts_status = Open3.capture3('aws sts get-caller-identity --query Account --output text')
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

    def should_refresh_credentials?
      return false unless @config['use_aws_cli']

      Time.now - @last_token_check > 1800 # 30 minutes
    end

    def mark_credentials_checked
      @last_token_check = Time.now
    end

    def refresh_aws_credentials(profile = nil)
      profile ||= @config['aws_profile'] || 'default'

      begin
        puts 'Attempting to refresh AWS SSO credentials...'.colorize(:cyan)

        # Try AWS SSO login
        _login_output, login_stderr, login_status = Open3.capture3("aws sso login --profile #{profile}")

        if login_status.success?
          puts 'AWS SSO credentials refreshed successfully!'.colorize(:green)

          # Save token information if available
          save_refreshed_credentials(profile)
          mark_credentials_checked
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

    def refresh_runtime_clients(codepipeline_client, sts_client)
      return [codepipeline_client, sts_client] unless @config['use_aws_cli']

      begin
        profile = @config['aws_profile'] || 'default'

        # Try AWS SSO login
        _login_output, login_stderr, login_status = Open3.capture3("aws sso login --profile #{profile}")

        if login_status.success?
          # Recreate the clients with refreshed credentials
          client_options = build_client_options

          new_codepipeline_client = Aws::CodePipeline::Client.new(client_options)
          new_sts_client = Aws::STS::Client.new(client_options)

          puts 'AWS credentials refreshed successfully!'.colorize(:green)
          mark_credentials_checked
          return [new_codepipeline_client, new_sts_client]
        else
          puts "Failed to refresh credentials: #{login_stderr}".colorize(:red)
          return [codepipeline_client, sts_client]
        end
      rescue StandardError => e
        puts "Error during credential refresh: #{e.message}".colorize(:red)
        return [codepipeline_client, sts_client]
      end
    end

    def refresh_runtime_codebuild_clients(codebuild_client, sts_client)
      return [codebuild_client, sts_client] unless @config['use_aws_cli']

      begin
        profile = @config['aws_profile'] || 'default'

        # Try AWS SSO login
        _login_output, login_stderr, login_status = Open3.capture3("aws sso login --profile #{profile}")

        if login_status.success?
          # Recreate the clients with refreshed credentials
          client_options = build_client_options

          new_codebuild_client = Aws::CodeBuild::Client.new(client_options)
          new_sts_client = Aws::STS::Client.new(client_options)

          puts 'AWS credentials refreshed successfully!'.colorize(:green)
          mark_credentials_checked
          return [new_codebuild_client, new_sts_client]
        else
          puts "Failed to refresh credentials: #{login_stderr}".colorize(:red)
          return [codebuild_client, sts_client]
        end
      rescue StandardError => e
        puts "Error during credential refresh: #{e.message}".colorize(:red)
        return [codebuild_client, sts_client]
      end
    end

    def refresh_runtime_unified_clients(codepipeline_client, codebuild_client, sts_client)
      return [codepipeline_client, codebuild_client, sts_client] unless @config['use_aws_cli']

      begin
        profile = @config['aws_profile'] || 'default'

        # Try AWS SSO login
        _login_output, login_stderr, login_status = Open3.capture3("aws sso login --profile #{profile}")

        if login_status.success?
          # Recreate the clients with refreshed credentials
          client_options = build_client_options

          new_codepipeline_client = Aws::CodePipeline::Client.new(client_options)
          new_codebuild_client = Aws::CodeBuild::Client.new(client_options)
          new_sts_client = Aws::STS::Client.new(client_options)

          puts 'AWS credentials refreshed successfully!'.colorize(:green)
          mark_credentials_checked
          return [new_codepipeline_client, new_codebuild_client, new_sts_client]
        else
          puts "Failed to refresh credentials: #{login_stderr}".colorize(:red)
          return [codepipeline_client, codebuild_client, sts_client]
        end
      rescue StandardError => e
        puts "Error during credential refresh: #{e.message}".colorize(:red)
        return [codepipeline_client, codebuild_client, sts_client]
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
                'last_refreshed' => Time.now.iso8601,
                'profile' => profile
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
end
