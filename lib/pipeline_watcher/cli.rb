# frozen_string_literal: true

require 'thor'
require 'cli/ui'
require_relative 'config/manager'
require_relative 'watcher'
require_relative 'ui/components'

module PipelineWatcher
  # Simplified CLI class using the new architecture
  # Easy for beginners to understand and modify
  class CLI < Thor

    # Handle version flag properly
    def self.exit_on_failure?
      true
    end

    desc 'version', 'Show version information'
    def version
      puts "AWS Pipeline Watcher v#{PipelineWatcher::VERSION}"
    end

    desc 'watch', 'Start monitoring pipelines and builds (default command)'
    def watch
      # Set up CLI-UI
      ::CLI::UI::StdoutRouter.enable

      watcher = Watcher.new
      watcher.start
    end

    desc 'config', 'Configure AWS credentials and monitoring settings'
    def config
      # Set up CLI-UI
      ::CLI::UI::StdoutRouter.enable

      config_manager = Config::Manager.new

      UI::Components.clear_screen
      show_welcome_message

      # Show current configuration if it exists
      if config_manager.valid?
        UI::Components.config_summary(config_manager)
        return unless UI::Components.confirm("Do you want to update this configuration?")
      end

      # Collect configuration from user
      new_config = collect_configuration(config_manager)

      # Save and validate
      config_manager.update(new_config)

      if config_manager.valid?
        UI::Components.success_message("Configuration saved successfully!")
        UI::Components.config_summary(config_manager)
      else
        UI::Components.validation_errors(config_manager.validation_errors)
        exit(1)
      end
    end

    desc 'status', 'Show current configuration and validation status'
    def status
      # Set up CLI-UI
      ::CLI::UI::StdoutRouter.enable

      config_manager = Config::Manager.new

      UI::Components.clear_screen
      UI::Components.config_summary(config_manager)

      if config_manager.valid?
        UI::Components.success_message("Configuration is valid and ready for monitoring")
      else
        UI::Components.validation_errors(config_manager.validation_errors)
      end
    end

    # Make 'watch' the default command
    default_task :watch

    private

    def show_welcome_message
      ::CLI::UI::Frame.open('AWS Pipeline Watcher Configuration', color: :cyan) do
        puts ::CLI::UI.fmt("{{bold:Welcome!}} Let's set up your monitoring configuration.")
        puts ""
        puts "This tool can monitor:"
        puts "• AWS CodePipeline executions"
        puts "• AWS CodeBuild project builds"
        puts ""
        puts "You'll need AWS credentials with appropriate permissions."
      end
      puts ""
    end

    def collect_configuration(config_manager)
      config = {}

      # AWS authentication method
      use_cli = UI::Components.confirm("Use AWS CLI for authentication? (Recommended)")
      config['use_aws_cli'] = use_cli

      if use_cli
        collect_aws_cli_config(config, config_manager)
      else
        collect_manual_credentials(config)
      end

      # AWS region
      default_region = config_manager.aws_region
      config['aws_region'] = UI::Components.ask(
        "AWS Region:",
        default: default_region
      )

      # Pipelines to monitor
      collect_pipeline_names(config, config_manager)

      # CodeBuild projects to monitor
      collect_build_project_names(config, config_manager)

      config
    end

    def collect_aws_cli_config(config, config_manager)
      # AWS profile
      default_profile = config_manager.aws_profile
      config['aws_profile'] = UI::Components.ask(
        "AWS CLI Profile:",
        default: default_profile
      )

      # Try to detect AWS account ID
      begin
        require_relative 'services/pipeline_service'
        temp_config = Config::Manager.new
        temp_config.update(config.merge('aws_region' => config_manager.aws_region))

        service = Services::PipelineService.new(temp_config)
        if service.credentials_valid?
          # In a real implementation, we'd extract account ID from STS
          # For simplicity, we'll ask the user
          UI::Components.info_message("AWS CLI credentials are valid!")
        else
          UI::Components.warning_message("Could not validate AWS CLI credentials. Please run 'aws sso login' first.")
        end
      rescue => e
        UI::Components.warning_message("Could not test AWS credentials: #{e.message}")
      end

      # AWS Account ID
      default_account_id = config_manager.aws_account_id
      config['aws_account_id'] = UI::Components.ask(
        "AWS Account ID (12 digits):",
        default: default_account_id
      )
    end

    def collect_manual_credentials(config)
      UI::Components.warning_message("Manual credentials are less secure than AWS CLI")

      config['aws_access_key_id'] = UI::Components.ask("AWS Access Key ID:")
      config['aws_secret_access_key'] = UI::Components.ask("AWS Secret Access Key:")
      config['aws_account_id'] = UI::Components.ask("AWS Account ID (12 digits):")
    end

    def collect_pipeline_names(config, config_manager)
      current_pipelines = config_manager.pipeline_names.join(', ')

      pipelines_input = UI::Components.ask(
        "Pipeline names to monitor (comma-separated):",
        default: current_pipelines
      )

      if pipelines_input && !pipelines_input.strip.empty?
        config['pipeline_names'] = pipelines_input.split(',').map(&:strip)
      else
        config['pipeline_names'] = []
      end
    end

    def collect_build_project_names(config, config_manager)
      current_builds = config_manager.build_project_names.join(', ')

      builds_input = UI::Components.ask(
        "CodeBuild project names to monitor (comma-separated):",
        default: current_builds
      )

      if builds_input && !builds_input.strip.empty?
        config['codebuild_project_names'] = builds_input.split(',').map(&:strip)
      else
        config['codebuild_project_names'] = []
      end
    end
  end
end
