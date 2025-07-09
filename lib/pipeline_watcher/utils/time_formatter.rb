# frozen_string_literal: true

module PipelineWatcher
  module Utils
    # Simple utility for formatting time durations
    module TimeFormatter
      # Format a duration in seconds into a human-readable string
      # @param duration [Integer] Duration in seconds
      # @return [String] Formatted duration (e.g., "1h 30m 45s")
      def self.format_duration(duration)
        return 'N/A' if duration.nil? || duration < 0

        hours = duration / 3600
        minutes = (duration % 3600) / 60
        seconds = duration % 60

        parts = []
        parts << "#{hours}h" if hours > 0
        parts << "#{minutes}m" if minutes > 0 || hours > 0
        parts << "#{seconds}s"

        parts.join(' ')
      end

      # Calculate duration from start time to now or end time
      # @param started_at [Time] When the process started
      # @param ended_at [Time, nil] When the process ended (nil for ongoing)
      # @return [Integer] Duration in seconds
      def self.calculate_duration(started_at, ended_at = nil)
        return 0 unless started_at

        end_time = ended_at || Time.now
        (end_time - started_at).to_i
      end

      # Format a timer display with status indicator
      # @param started_at [Time] When the process started
      # @param status [String] Current status (InProgress, Succeeded, Failed, etc.)
      # @param ended_at [Time, nil] When the process ended
      # @return [String] Formatted timer with status
      def self.format_timer(started_at, status, ended_at = nil)
        return 'N/A' unless started_at

        duration = calculate_duration(started_at, ended_at)
        formatted_duration = format_duration(duration)

        case status
        when 'InProgress', 'IN_PROGRESS'
          "#{formatted_duration} (running)"
        when 'Succeeded', 'SUCCEEDED'
          "#{formatted_duration} (completed)"
        when 'Failed', 'FAILED'
          "#{formatted_duration} (failed)"
        when 'Stopped'
          "#{formatted_duration} (stopped)"
        else
          formatted_duration
        end
      end
    end
  end
end
