# frozen_string_literal: true

require_relative 'config/manager'
require_relative 'services/pipeline_service'
require_relative 'services/build_service'
require_relative 'ui/renderer'
require_relative 'data/models'
require_relative 'utils/time_formatter'

module PipelineWatcher
  # Main watcher class that orchestrates all components
  # This is the simplified entry point that makes it easy for beginners to understand the flow
  class Watcher
    attr_reader :config, :renderer, :monitoring_data

    def initialize
      @config = Config::Manager.new
      @renderer = UI::Renderer.new
      @monitoring_data = Data::MonitoringData.new
      @pipeline_service = nil
      @build_service = nil
    end

    # Start monitoring pipelines and builds
    # This is the main entry point for the watcher
    def start
      setup_signal_handlers
      validate_configuration
      initialize_services
      run_monitoring_loop
    rescue Interrupt
      shutdown_gracefully
    rescue StandardError => e
      handle_unexpected_error(e)
    end

    private

    # Set up signal handlers for graceful shutdown
    def setup_signal_handlers
      trap('INT') do
        puts "\nShutting down gracefully..."
        exit(0)
      end
    end

    # Validate that configuration is ready for monitoring
    def validate_configuration
      unless @config.valid?
        @renderer.render_config_errors(@config)
        exit(1)
      end
    end

    # Initialize AWS services
    def initialize_services
      @pipeline_service = Services::PipelineService.new(@config)
      @build_service = Services::BuildService.new(@config)
    end

    # Main monitoring loop
    def run_monitoring_loop
      loop do
        begin
          # Show initial render first time
          if @monitoring_data.total_items == 0
            update_monitoring_data
            @renderer.render(@monitoring_data)
          else
            # Show loading indicator during refresh
            show_refresh_indicator
            update_monitoring_data
            @renderer.render(@monitoring_data)
          end
          wait_for_next_update
        rescue Aws::Errors::ServiceError => e
          handle_aws_error(e)
        rescue StandardError => e
          handle_monitoring_error(e)
        end
      end
    end

    # Fetch latest data from AWS services
    def update_monitoring_data
      @monitoring_data = Data::MonitoringData.new

      # Fetch pipeline data
      unless @config.pipeline_names.empty?
        pipelines = @pipeline_service.fetch_all_pipeline_info(@config.pipeline_names)
        pipelines.each { |pipeline| @monitoring_data.add_pipeline(pipeline) }
      end

      # Fetch build data
      unless @config.build_project_names.empty?
        builds = @build_service.fetch_all_build_info(@config.build_project_names)
        builds.each { |build| @monitoring_data.add_build(build) }
      end
    end

    # Wait before next update
    def wait_for_next_update
      sleep(5)
    end

    # Show refresh indicator
    def show_refresh_indicator
      # Save cursor position
      print "\033[s"

      # Move to bottom of screen and show loading
      print "\033[999;1H"
      print "\033[K" # Clear line
      print "⟳ Fetching latest data..."

      # Restore cursor position
      print "\033[u"
      $stdout.flush
    end

    # Handle AWS-specific errors (usually credential issues)
    def handle_aws_error(error)
      if credential_error?(error.message)
        @renderer.render_error("AWS credentials are invalid or expired")
        sleep(10)
      else
        @renderer.render_error("AWS Error: #{error.message}")
        sleep(10)
      end
    end

    # Handle general monitoring errors
    def handle_monitoring_error(error)
      @renderer.render_error("Monitoring Error: #{error.message}")
      sleep(10)
    end

    # Handle unexpected errors
    def handle_unexpected_error(error)
      puts "Unexpected error: #{error.message}"
      puts error.backtrace.join("\n")
      exit(1)
    end

    # Check if error is related to credentials
    def credential_error?(message)
      message.include?('token') ||
        message.include?('expire') ||
        message.include?('credential') ||
        message.include?('unauthorized') ||
        message.include?('access denied')
    end

    # Graceful shutdown
    def shutdown_gracefully
      puts "Goodbye!"
      exit(0)
    end
  end
end
