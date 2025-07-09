# frozen_string_literal: true

require 'cli/ui'
require 'stringio'
require_relative 'components'

module PipelineWatcher
  module UI
    # Main UI renderer that orchestrates the display
    # This class makes it easy for beginners to customize the overall layout
    class Renderer
      def initialize
        @first_render = true
        @screen_height = nil
        @content_lines = []
      end

      # Render the complete UI with monitoring data
      # @param monitoring_data [Data::MonitoringData] All pipeline and build data
      def render(monitoring_data)
        if @first_render
          prepare_initial_screen
          @first_render = false
        end

        refresh_screen(monitoring_data)
      end

      # Render error state when credentials are invalid
      # @param error_message [String] Error message to display
      def render_error(error_message)
        Components.clear_screen
        Components.error_message(error_message)
        Components.info_message("Please run: aws sso login")
        Components.footer
      end

      # Render configuration errors
      # @param config [Config::Manager] Configuration manager
      def render_config_errors(config)
        Components.clear_screen
        Components.validation_errors(config.validation_errors)
        Components.info_message("Run 'aws-pipeline-watcher config' to set up monitoring")
      end

      # Render loading state
      # @param message [String] Loading message
      def render_loading(message = "Fetching pipeline and build data...")
        Components.loading_spinner(message)
      end

      private

      # Prepare the initial screen setup
      def prepare_initial_screen
        Components.clear_screen

        # Hide cursor for cleaner display
        print "\033[?25l"

        # Get terminal height for proper scrolling
        @screen_height = `tput lines`.to_i rescue 24

        # Set up signal handler to restore cursor on exit
        at_exit { print "\033[?25h" }
      end

      # Refresh the screen with current data
      # @param monitoring_data [Data::MonitoringData] All pipeline and build data
      def refresh_screen(monitoring_data)
        # Build content as array of lines
        @content_lines = []

        capture_header(monitoring_data)
        capture_pipelines(monitoring_data.pipelines)
        capture_builds(monitoring_data.builds)
        capture_footer

        # Move cursor to top-left and clear screen, then print all content at once
        print "\033[H\033[2J"
        print @content_lines.join("\n")
        print "\n"

        # Flush output immediately
        $stdout.flush
      end

      # Capture header content
      # @param monitoring_data [Data::MonitoringData] All pipeline and build data
      def capture_header(monitoring_data)
        header_content = capture_component_output do
          Components.header(
            monitoring_data.pipelines.length,
            monitoring_data.builds.length
          )
        end
        @content_lines.concat(header_content)
      end

      # Capture pipeline content
      # @param pipelines [Array<Data::PipelineInfo>] Pipeline data
      def capture_pipelines(pipelines)
        return if pipelines.empty?

        @content_lines << ::CLI::UI.fmt("{{bold:{{cyan:📦 CodePipelines}}}}")

        pipelines.each do |pipeline|
          pipeline_content = capture_component_output do
            Components.pipeline_item(pipeline)
          end
          @content_lines.concat(pipeline_content)
        end
        @content_lines << ""
      end

      # Capture build content
      # @param builds [Array<Data::BuildInfo>] Build data
      def capture_builds(builds)
        return if builds.empty?

        @content_lines << ::CLI::UI.fmt("{{bold:{{cyan:🔨 CodeBuild Projects}}}}")

        builds.each do |build|
          build_content = capture_component_output do
            Components.build_item(build)
          end
          @content_lines.concat(build_content)
        end
        @content_lines << ""
      end

      # Capture footer content
      def capture_footer
        footer_content = capture_component_output do
          Components.footer
        end
        @content_lines.concat(footer_content)
      end

      # Helper method to capture component output
      # @yield Block that produces output
      # @return [Array<String>] Array of output lines
      def capture_component_output
        old_stdout = $stdout
        $stdout = StringIO.new
        yield
        output = $stdout.string
        $stdout = old_stdout

        # Split into lines and remove empty trailing line
        lines = output.split("\n")
        lines.pop if lines.last == ""
        lines
      end
    end
  end
end
