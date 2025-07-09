# frozen_string_literal: true

require 'aws-sdk-codepipeline'
require 'aws-sdk-sts'
require 'json'

module PipelineWatcher
  module Services
    # Service for fetching AWS CodePipeline data
    # Simplified interface that returns our data models
    class PipelineService
      def initialize(config_manager)
        @config = config_manager
        @client = create_client
      end

      # Fetch information for a single pipeline
      # @param pipeline_name [String] Name of the pipeline
      # @return [Data::PipelineInfo] Pipeline information
      def fetch_pipeline_info(pipeline_name)
        execution = get_latest_execution(pipeline_name)
        return create_empty_pipeline_info(pipeline_name) unless execution

        step_info = get_current_step_info(pipeline_name, execution.pipeline_execution_id)
        commit_info = extract_commit_info(execution)

        Data::PipelineInfo.new(
          name: pipeline_name,
          status: determine_actual_status(execution.status, step_info),
          current_step: step_info[:step],
          started_at: execution.start_time,
          commit_hash: commit_info[:hash],
          commit_message: commit_info[:message],
          error_details: step_info[:error_details] || []
        )
      rescue Aws::Errors::ServiceError => e
        create_error_pipeline_info(pipeline_name, e.message)
      end

      # Fetch information for multiple pipelines
      # @param pipeline_names [Array<String>] Names of pipelines
      # @return [Array<Data::PipelineInfo>] Array of pipeline information
      def fetch_all_pipeline_info(pipeline_names)
        pipeline_names.map { |name| fetch_pipeline_info(name) }
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

      # Create AWS CodePipeline client
      def create_client
        Aws::CodePipeline::Client.new(build_client_options)
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

      # Get the latest execution for a pipeline
      def get_latest_execution(pipeline_name)
        response = @client.list_pipeline_executions({
          pipeline_name: pipeline_name,
          max_results: 1
        })

        response.pipeline_execution_summaries.first
      end

      # Get current step information for a pipeline execution
      def get_current_step_info(pipeline_name, execution_id)
        response = @client.list_action_executions({
          pipeline_name: pipeline_name,
          filter: {
            pipeline_execution_id: execution_id
          }
        })

        # Find currently running or most recent failed action
        running_action = response.action_execution_details.find { |action| action.status == 'InProgress' }
        failed_action = response.action_execution_details.find { |action| action.status == 'Failed' }

        if running_action
          {
            step: "#{running_action.stage_name}:#{running_action.action_name}",
            actual_status: 'InProgress',
            error_details: nil
          }
        elsif failed_action
          {
            step: "#{failed_action.stage_name}:#{failed_action.action_name} (FAILED)",
            actual_status: 'Failed',
            error_details: extract_failure_details(failed_action)
          }
        else
          {
            step: 'Completed',
            actual_status: 'Succeeded',
            error_details: nil
          }
        end
      rescue StandardError
        {
          step: 'Unknown',
          actual_status: nil,
          error_details: nil
        }
      end

      # Extract commit information from execution
      def extract_commit_info(execution)
        return { hash: nil, message: nil } unless execution.source_revisions&.first

        source_revision = execution.source_revisions.first
        revision_id = source_revision.revision_id
        commit_message = extract_commit_message(source_revision.revision_summary)

        {
          hash: revision_id,
          message: commit_message
        }
      end

      # Extract clean commit message from revision summary
      def extract_commit_message(revision_summary)
        return nil unless revision_summary && !revision_summary.empty?

        # Try to parse JSON if it looks like JSON (from GitHub/CodeCommit)
        if revision_summary.start_with?('{') && revision_summary.include?('CommitMessage')
          begin
            parsed = JSON.parse(revision_summary)
            message = parsed['CommitMessage']
            return truncate_message(message) if message
          rescue JSON::ParserError
            # Fall through to use original string
          end
        end

        truncate_message(revision_summary)
      end

      # Truncate long commit messages
      def truncate_message(message)
        return nil unless message
        message.length > 80 ? "#{message[0..77]}..." : message
      end

      # Determine the actual status based on execution status and step info
      def determine_actual_status(execution_status, step_info)
        # If execution says InProgress but steps show Completed, trust the steps
        if execution_status == 'InProgress' && step_info[:step] == 'Completed'
          'Succeeded'
        else
          step_info[:actual_status] || execution_status
        end
      end

      # Extract failure details from failed action
      def extract_failure_details(failed_action)
        details = []

        # Get error message from action execution
        if failed_action.error_details&.message
          error_msg = failed_action.error_details.message
          error_msg = "#{error_msg[0..120]}..." if error_msg.length > 120
          details << "Error: #{error_msg}"
        end

        # Get failure summary if available
        if failed_action.output&.execution_result&.external_execution_summary
          summary = failed_action.output.execution_result.external_execution_summary
          summary = "#{summary[0..80]}..." if summary.length > 80
          details << "Summary: #{summary}"
        end

        # Provide generic info if no specific details
        if details.empty?
          details << "Action failed in #{failed_action.stage_name} stage"
          details << "Check AWS Console for detailed error information"
        end

        details[0..2] # Limit to 3 lines
      rescue StandardError
        ["Failed action details unavailable"]
      end

      # Create pipeline info for pipeline with no executions
      def create_empty_pipeline_info(pipeline_name)
        Data::PipelineInfo.new(
          name: pipeline_name,
          status: 'No executions',
          current_step: 'No executions found'
        )
      end

      # Create pipeline info for error cases
      def create_error_pipeline_info(pipeline_name, error_message)
        Data::PipelineInfo.new(
          name: pipeline_name,
          status: 'Error',
          current_step: 'Error fetching data',
          error_details: [error_message]
        )
      end
    end
  end
end
