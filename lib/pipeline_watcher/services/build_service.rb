# frozen_string_literal: true

require 'aws-sdk-codebuild'
require 'aws-sdk-sts'

module PipelineWatcher
  module Services
    # Service for fetching AWS CodeBuild data
    # Simplified interface that returns our data models
    class BuildService
      def initialize(config_manager)
        @config = config_manager
        @client = create_client
      end

      # Fetch information for a single build project
      # @param project_name [String] Name of the build project
      # @return [Data::BuildInfo] Build information
      def fetch_build_info(project_name)
        build = get_latest_build(project_name)
        return create_empty_build_info(project_name) unless build

        phase_info = get_current_phase_info(build)
        commit_info = extract_commit_info(build)

        Data::BuildInfo.new(
          name: project_name,
          status: build.build_status,
          current_phase: phase_info[:phase],
          started_at: build.start_time,
          commit_hash: commit_info[:hash],
          commit_message: commit_info[:message],
          error_details: phase_info[:error_details] || []
        )
      rescue Aws::Errors::ServiceError => e
        create_error_build_info(project_name, e.message)
      end

      # Fetch information for multiple build projects
      # @param project_names [Array<String>] Names of build projects
      # @return [Array<Data::BuildInfo>] Array of build information
      def fetch_all_build_info(project_names)
        project_names.map { |name| fetch_build_info(name) }
      end

      # Test if credentials are valid
      # @return [Boolean] True if credentials work
      def credentials_valid?
        sts_client = Aws::STS::Client.new(build_client_options)
        sts_client.get_caller_identity
        true
      rescue Aws::Errors::ServiceError
        false
      end

      private

      # Create AWS CodeBuild client
      def create_client
        Aws::CodeBuild::Client.new(build_client_options)
      end

      # Build options for AWS client
      def build_client_options
        options = { region: @config.aws_region }

        if @config.using_aws_cli?
          options[:profile] = @config.aws_profile
        else
          options[:access_key_id] = @config.get('aws_access_key_id')
          options[:secret_access_key] = @config.get('aws_secret_access_key')
        end

        options
      end

      # Get the latest build for a project
      def get_latest_build(project_name)
        # Get list of builds for this project
        response = @client.list_builds_for_project({
          project_name: project_name,
          sort_order: 'DESCENDING'
        })

        return nil if response.ids.empty?

        # Get detailed information for the latest build
        builds_response = @client.batch_get_builds({
          ids: [response.ids.first]
        })

        builds_response.builds.first
      end

      # Get current phase information for a build
      def get_current_phase_info(build)
        case build.build_status
        when 'IN_PROGRESS'
          current_phase = get_current_build_phase(build)
          {
            phase: "#{current_phase} (running)",
            error_details: nil
          }
        when 'FAILED'
          {
            phase: "#{get_failed_phase(build)} (FAILED)",
            error_details: extract_failure_details(build)
          }
        when 'SUCCEEDED'
          {
            phase: 'Completed',
            error_details: nil
          }
        when 'STOPPED'
          {
            phase: 'Stopped',
            error_details: ['Build was stopped']
          }
        else
          {
            phase: build.build_status,
            error_details: nil
          }
        end
      end

      # Get the current build phase for in-progress builds
      def get_current_build_phase(build)
        return 'UNKNOWN' unless build.phases

        # Find the currently running phase
        current_phase = build.phases.find { |phase| phase.phase_status == 'IN_PROGRESS' }
        return current_phase.phase_type if current_phase

        # If no phase is currently in progress, find the last completed phase
        completed_phases = build.phases.select { |phase| phase.phase_status == 'SUCCEEDED' }
        return completed_phases.last.phase_type if completed_phases.any?

        'UNKNOWN'
      end

      # Get the phase that failed for failed builds
      def get_failed_phase(build)
        return 'UNKNOWN' unless build.phases

        failed_phase = build.phases.find { |phase| phase.phase_status == 'FAILED' }
        return failed_phase.phase_type if failed_phase

        'BUILD'
      end

      # Extract commit information from build
      def extract_commit_info(build)
        return { hash: nil, message: nil } unless build.source&.location

        # For CodeCommit and GitHub, try to extract commit hash
        if build.resolved_source_version
          {
            hash: build.resolved_source_version,
            message: nil # CodeBuild doesn't typically provide commit messages
          }
        else
          { hash: nil, message: nil }
        end
      end

      # Extract failure details from failed build
      def extract_failure_details(build)
        details = []

        # Get logs information
        if build.logs&.cloud_watch_logs&.status == 'ENABLED'
          if build.logs.cloud_watch_logs.group_name
            details << "Logs: #{build.logs.cloud_watch_logs.group_name}"
          end
        end

        # Get failed phase information
        if build.phases
          failed_phase = build.phases.find { |phase| phase.phase_status == 'FAILED' }
          if failed_phase&.contexts&.any?
            context = failed_phase.contexts.first
            if context.message
              message = context.message.length > 100 ? "#{context.message[0..97]}..." : context.message
              details << "Error: #{message}"
            end
          end
        end

        # Generic failure info if no specific details
        if details.empty?
          details << "Build failed - check CloudWatch logs for details"
          if build.logs&.cloud_watch_logs&.group_name
            details << "Log group: #{build.logs.cloud_watch_logs.group_name}"
          end
        end

        details[0..2] # Limit to 3 lines
      rescue StandardError
        ["Build failure details unavailable"]
      end

      # Create build info for project with no builds
      def create_empty_build_info(project_name)
        Data::BuildInfo.new(
          name: project_name,
          status: 'No builds',
          current_phase: 'No builds found'
        )
      end

      # Create build info for error cases
      def create_error_build_info(project_name, error_message)
        Data::BuildInfo.new(
          name: project_name,
          status: 'Error',
          current_phase: 'Error fetching data',
          error_details: [error_message]
        )
      end
    end
  end
end
