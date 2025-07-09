# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/pipeline_watcher/utils/time_formatter'

RSpec.describe PipelineWatcher::Utils::TimeFormatter do
  describe '.format_duration' do
    it 'formats seconds only' do
      expect(described_class.format_duration(45)).to eq('45s')
    end

    it 'formats minutes and seconds' do
      expect(described_class.format_duration(125)).to eq('2m 5s')
    end

    it 'formats hours, minutes and seconds' do
      expect(described_class.format_duration(3665)).to eq('1h 1m 5s')
    end

    it 'formats hours and minutes without seconds when seconds is 0' do
      expect(described_class.format_duration(3600)).to eq('1h 0m 0s')
    end

    it 'formats large durations' do
      expect(described_class.format_duration(7323)).to eq('2h 2m 3s')
    end

    it 'returns N/A for nil duration' do
      expect(described_class.format_duration(nil)).to eq('N/A')
    end

    it 'returns N/A for negative duration' do
      expect(described_class.format_duration(-10)).to eq('N/A')
    end

    it 'formats zero duration' do
      expect(described_class.format_duration(0)).to eq('0s')
    end
  end

  describe '.calculate_duration' do
    let(:start_time) { Time.now - 3600 } # 1 hour ago

    it 'calculates duration from start time to now' do
      duration = described_class.calculate_duration(start_time)
      expect(duration).to be_within(5).of(3600) # Allow 5 second tolerance
    end

    it 'calculates duration from start time to end time' do
      end_time = start_time + 1800 # 30 minutes later
      duration = described_class.calculate_duration(start_time, end_time)
      expect(duration).to eq(1800)
    end

    it 'returns 0 for nil start time' do
      expect(described_class.calculate_duration(nil)).to eq(0)
    end

    it 'handles end time before start time' do
      end_time = start_time - 600 # 10 minutes before start
      duration = described_class.calculate_duration(start_time, end_time)
      expect(duration).to eq(-600)
    end
  end

  describe '.format_timer' do
    let(:started_at) { Time.now - 3600 } # 1 hour ago

    it 'formats timer for InProgress status' do
      result = described_class.format_timer(started_at, 'InProgress')
      expect(result).to match(/1h 0m \d+s \(running\)/)
    end

    it 'formats timer for IN_PROGRESS status (CodeBuild)' do
      result = described_class.format_timer(started_at, 'IN_PROGRESS')
      expect(result).to match(/1h 0m \d+s \(running\)/)
    end

    it 'formats timer for Succeeded status' do
      end_time = started_at + 1800 # 30 minutes later
      result = described_class.format_timer(started_at, 'Succeeded', end_time)
      expect(result).to eq('30m 0s (completed)')
    end

    it 'formats timer for SUCCEEDED status (CodeBuild)' do
      end_time = started_at + 900 # 15 minutes later
      result = described_class.format_timer(started_at, 'SUCCEEDED', end_time)
      expect(result).to eq('15m 0s (completed)')
    end

    it 'formats timer for Failed status' do
      end_time = started_at + 600 # 10 minutes later
      result = described_class.format_timer(started_at, 'Failed', end_time)
      expect(result).to eq('10m 0s (failed)')
    end

    it 'formats timer for FAILED status (CodeBuild)' do
      end_time = started_at + 300 # 5 minutes later
      result = described_class.format_timer(started_at, 'FAILED', end_time)
      expect(result).to eq('5m 0s (failed)')
    end

    it 'formats timer for Stopped status' do
      end_time = started_at + 1200 # 20 minutes later
      result = described_class.format_timer(started_at, 'Stopped', end_time)
      expect(result).to eq('20m 0s (stopped)')
    end

    it 'formats timer for unknown status' do
      end_time = started_at + 180 # 3 minutes later
      result = described_class.format_timer(started_at, 'Unknown', end_time)
      expect(result).to eq('3m 0s')
    end

    it 'returns N/A for nil start time' do
      result = described_class.format_timer(nil, 'InProgress')
      expect(result).to eq('N/A')
    end

    it 'calculates ongoing duration when no end time provided' do
      result = described_class.format_timer(started_at, 'InProgress')
      expect(result).to match(/1h 0m \d+s \(running\)/)
    end
  end
end
