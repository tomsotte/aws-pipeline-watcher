# frozen_string_literal: true

module PipelineWatcher
  module TimerUtils
    def calculate_timer_info(started_at, status, ended_at = nil)
      return 'N/A' unless started_at

      time_since_started = format_time_since(started_at)

      if status == 'IN_PROGRESS' || status == 'InProgress'
        duration = Time.now - started_at
        duration_formatted = format_duration(duration)
        "Started #{time_since_started}, running for #{duration_formatted}"
      elsif ended_at
        duration = ended_at - started_at
        duration_formatted = format_duration(duration)
        "Started #{time_since_started}, completed in #{duration_formatted}"
      else
        duration = Time.now - started_at
        duration_formatted = format_duration(duration)
        case status
        when 'Succeeded', 'SUCCEEDED'
          "Started #{time_since_started}, completed in #{duration_formatted}"
        when 'Failed', 'FAILED', 'FAULT', 'TIMED_OUT'
          "Started #{time_since_started}, failed after #{duration_formatted}"
        when 'Stopped', 'STOPPED'
          "Started #{time_since_started}, stopped after #{duration_formatted}"
        else
          "Started #{time_since_started}, duration #{duration_formatted}"
        end
      end
    end

    def format_duration(seconds)
      hours = (seconds / 3600).to_i
      minutes = ((seconds % 3600) / 60).to_i
      secs = (seconds % 60).to_i

      if hours.positive?
        "#{hours}h #{minutes}m #{secs}s"
      elsif minutes.positive?
        "#{minutes}m #{secs}s"
      else
        "#{secs}s"
      end
    end

    def format_time_since(started_at)
      seconds_ago = Time.now - started_at

      if seconds_ago < 60
        "#{seconds_ago.to_i}s ago"
      elsif seconds_ago < 3600
        "#{(seconds_ago / 60).to_i}m ago"
      elsif seconds_ago < 86400
        hours = (seconds_ago / 3600).to_i
        minutes = ((seconds_ago % 3600) / 60).to_i
        if minutes.zero?
          "#{hours}h ago"
        else
          "#{hours}h #{minutes}m ago"
        end
      else
        days = (seconds_ago / 86400).to_i
        hours = ((seconds_ago % 86400) / 3600).to_i
        if hours.zero?
          "#{days}d ago"
        else
          "#{days}d #{hours}h ago"
        end
      end
    end
  end
end
