# frozen_string_literal: true

require 'cli/ui'
require_relative '../utils/time_formatter'

module PipelineWatcher
  module UI
    # UI components using CLI-UI for better user experience
    # These components make it easy for beginners to modify the interface
    module Components

      # Status icons and colors for different states
      STATUS_ICONS = {
        'InProgress' => '{{yellow:⚡}}',
        'IN_PROGRESS' => '{{yellow:⚡}}',
        'Succeeded' => '{{green:✓}}',
        'SUCCEEDED' => '{{green:✓}}',
        'Failed' => '{{red:✗}}',
        'FAILED' => '{{red:✗}}',
        'Stopped' => '{{magenta:⏹}}',
        'No executions' => '{{cyan:○}}',
        'No builds' => '{{cyan:○}}',
        'Error' => '{{red:⚠}}'
      }.freeze

      # Display the main header with current time
      # @param pipeline_count [Integer] Number of pipelines being monitored
      # @param build_count [Integer] Number of builds being monitored
      def self.header(pipeline_count, build_count)
        ::CLI::UI::Frame.open('AWS Pipeline Watcher', color: :cyan) do
          puts ::CLI::UI.fmt("{{bold:Monitoring}} {{blue:#{pipeline_count}}} pipelines and {{blue:#{build_count}}} builds")
          puts ::CLI::UI.fmt("{{cyan:Last updated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}}}")
          puts ::CLI::UI.fmt("{{cyan:Press Ctrl+C to exit}}")
        end
      end

      # Display a single pipeline item
      # @param pipeline [Data::PipelineInfo] Pipeline information
      def self.pipeline_item(pipeline)
        icon = STATUS_ICONS[pipeline.status] || '{{cyan:?}}'

        status_text = pipeline.current_step || pipeline.status
        timer_text = ""
        if pipeline.started_at
          timer = Utils::TimeFormatter.format_timer(pipeline.started_at, pipeline.status)
          timer_text = " | {{cyan:#{timer}}}"
        end

        commit_display = pipeline.display_commit
        puts ::CLI::UI.fmt("#{icon} {{bold:#{pipeline.name}}} - #{status_text}#{timer_text}")
        puts ::CLI::UI.fmt("   {{cyan:#{commit_display}}}")

        # Error details for failed pipelines
        if pipeline.failed? && !pipeline.error_details.empty?
          pipeline.error_details.each do |detail|
            puts ::CLI::UI.fmt("   {{red:⚠ #{detail}}}")
          end
        end
      end

      # Display a single build item
      # @param build [Data::BuildInfo] Build information
      def self.build_item(build)
        icon = STATUS_ICONS[build.status] || '{{cyan:?}}'

        phase_text = build.current_phase || build.status
        timer_text = ""
        if build.started_at
          timer = Utils::TimeFormatter.format_timer(build.started_at, build.status)
          timer_text = " | {{cyan:#{timer}}}"
        end

        commit_display = build.display_commit
        puts ::CLI::UI.fmt("#{icon} {{bold:#{build.name}}} - #{phase_text}#{timer_text}")
        puts ::CLI::UI.fmt("   {{cyan:#{commit_display}}}")

        # Error details for failed builds
        if build.failed? && !build.error_details.empty?
          build.error_details.each do |detail|
            puts ::CLI::UI.fmt("   {{red:⚠ #{detail}}}")
          end
        end
      end

      # Display an error message
      # @param message [String] Error message to display
      def self.error_message(message)
        ::CLI::UI::Frame.open('Error', color: :red) do
          puts ::CLI::UI.fmt("{{red:#{message}}}")
        end
      end

      # Display a warning message
      # @param message [String] Warning message to display
      def self.warning_message(message)
        ::CLI::UI::Frame.open('Warning', color: :yellow) do
          puts ::CLI::UI.fmt("{{yellow:#{message}}}")
        end
      end

      # Display an informational message
      # @param message [String] Info message to display
      def self.info_message(message)
        ::CLI::UI::Frame.open('Info', color: :blue) do
          puts ::CLI::UI.fmt("{{blue:#{message}}}")
        end
      end

      # Display a success message
      # @param message [String] Success message to display
      def self.success_message(message)
        ::CLI::UI::Frame.open('Success', color: :green) do
          puts ::CLI::UI.fmt("{{green:#{message}}}")
        end
      end

      # Clear the screen and move cursor to top
      def self.clear_screen
        print "\033[H\033[2J"
      end

      # Display a loading spinner for the given duration
      # @param message [String] Message to show with spinner
      # @param duration [Integer] Duration in seconds
      def self.loading_spinner(message, duration = 5)
        ::CLI::UI::Spinner.spin(message) do
          sleep(duration)
        end
      end

      # Display configuration summary in a nice format
      # @param config [Config::Manager] Configuration manager
      def self.config_summary(config)
        ::CLI::UI::Frame.open('Configuration Summary', color: :cyan) do
          puts ::CLI::UI.fmt("{{bold:AWS Mode:}} #{config.using_aws_cli? ? 'CLI' : 'Manual credentials'}")
          puts ::CLI::UI.fmt("{{bold:Region:}} #{config.aws_region}")
          puts ::CLI::UI.fmt("{{bold:Profile:}} #{config.aws_profile}") if config.using_aws_cli?
          puts ::CLI::UI.fmt("{{bold:Account ID:}} #{config.aws_account_id || 'Not set'}")

          unless config.pipeline_names.empty?
            puts ::CLI::UI.fmt("{{bold:Pipelines:}}")
            config.pipeline_names.each { |name| puts "  • #{name}" }
          end

          unless config.build_project_names.empty?
            puts ::CLI::UI.fmt("{{bold:Build Projects:}}")
            config.build_project_names.each { |name| puts "  • #{name}" }
          end
        end
      end

      # Display validation errors
      # @param errors [Array<String>] List of validation errors
      def self.validation_errors(errors)
        ::CLI::UI::Frame.open('Configuration Errors', color: :red) do
          puts ::CLI::UI.fmt("{{red:Please fix the following issues:}}")
          errors.each { |error| puts ::CLI::UI.fmt("{{red:• #{error}}}") }
        end
      end

      # Ask user for input with a prompt
      # @param question [String] Question to ask
      # @param default [String] Default value
      # @return [String] User input
      def self.ask(question, default: nil)
        if default
          ::CLI::UI.ask("#{question}", default: default)
        else
          ::CLI::UI.ask("#{question}")
        end
      end

      # Ask user for confirmation (y/n)
      # @param question [String] Question to ask
      # @return [Boolean] True if user confirmed
      def self.confirm(question)
        ::CLI::UI.confirm("#{question}")
      end

      # Display a footer with refresh information
      def self.footer
        puts ::CLI::UI.fmt("{{cyan:⟳ Refreshing every 5 seconds... (Press Ctrl+C to exit)}}")
      end

      # Display a loading indicator while fetching data
      def self.loading_indicator
        puts ::CLI::UI.fmt("{{yellow:⟳ Fetching latest data...}}")
      end

      # Display refresh status with timestamp
      def self.refresh_status
        puts ::CLI::UI.fmt("{{cyan:✓ Updated at #{Time.now.strftime('%H:%M:%S')}}}")
      end

      private

      # Get appropriate frame color based on status
      # @param status [String] Status string
      # @return [Symbol] Color symbol for CLI-UI
      def self.frame_color(status)
        case status
        when 'InProgress', 'IN_PROGRESS'
          :yellow
        when 'Succeeded', 'SUCCEEDED'
          :green
        when 'Failed', 'FAILED'
          :red
        when 'Stopped'
          :magenta
        when 'Error'
          :red
        else
          :cyan
        end
      end
    end
  end
end
