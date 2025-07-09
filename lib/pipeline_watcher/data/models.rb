# frozen_string_literal: true

module PipelineWatcher
  module Data
    # Simple data structure for pipeline information
    class PipelineInfo
      attr_accessor :name, :status, :current_step, :started_at, :commit_hash, :commit_message, :error_details

      def initialize(name:, status: 'Unknown', current_step: nil, started_at: nil, commit_hash: nil, commit_message: nil, error_details: [])
        @name = name
        @status = status
        @current_step = current_step
        @started_at = started_at
        @commit_hash = commit_hash
        @commit_message = commit_message
        @error_details = error_details
      end

      def failed?
        status == 'Failed'
      end

      def in_progress?
        status == 'InProgress'
      end

      def succeeded?
        status == 'Succeeded'
      end

      def short_commit_hash
        return 'N/A' unless commit_hash
        commit_hash.length > 8 ? commit_hash[0..7] : commit_hash
      end

      def display_commit
        return 'N/A' unless commit_hash
        if commit_message && !commit_message.empty?
          first_line = commit_message.split("\n").first.strip
          "#{short_commit_hash}: #{first_line}"
        else
          short_commit_hash
        end
      end
    end

    # Simple data structure for CodeBuild project information
    class BuildInfo
      attr_accessor :name, :status, :current_phase, :started_at, :commit_hash, :commit_message, :error_details

      def initialize(name:, status: 'Unknown', current_phase: nil, started_at: nil, commit_hash: nil, commit_message: nil, error_details: [])
        @name = name
        @status = status
        @current_phase = current_phase
        @started_at = started_at
        @commit_hash = commit_hash
        @commit_message = commit_message
        @error_details = error_details
      end

      def failed?
        status == 'FAILED'
      end

      def in_progress?
        status == 'IN_PROGRESS'
      end

      def succeeded?
        status == 'SUCCEEDED'
      end

      def short_commit_hash
        return 'N/A' unless commit_hash
        commit_hash.length > 8 ? commit_hash[0..7] : commit_hash
      end

      def display_commit
        return 'N/A' unless commit_hash
        if commit_message && !commit_message.empty?
          first_line = commit_message.split("\n").first.strip
          "#{short_commit_hash}: #{first_line}"
        else
          short_commit_hash
        end
      end
    end

    # Container for all monitoring data
    class MonitoringData
      attr_accessor :pipelines, :builds, :last_updated

      def initialize
        @pipelines = []
        @builds = []
        @last_updated = Time.now
      end

      def add_pipeline(pipeline_info)
        @pipelines << pipeline_info
        update_timestamp
      end

      def add_build(build_info)
        @builds << build_info
        update_timestamp
      end

      def update_pipeline(name, &block)
        pipeline = @pipelines.find { |p| p.name == name }
        return unless pipeline
        block.call(pipeline)
        update_timestamp
      end

      def update_build(name, &block)
        build = @builds.find { |b| b.name == name }
        return unless build
        block.call(build)
        update_timestamp
      end

      def total_items
        @pipelines.length + @builds.length
      end

      def has_failures?
        @pipelines.any?(&:failed?) || @builds.any?(&:failed?)
      end

      def has_in_progress?
        @pipelines.any?(&:in_progress?) || @builds.any?(&:in_progress?)
      end

      private

      def update_timestamp
        @last_updated = Time.now
      end
    end
  end
end
