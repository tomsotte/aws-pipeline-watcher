# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/pipeline_watcher/data/models'

RSpec.describe PipelineWatcher::Data do
  describe PipelineWatcher::Data::PipelineInfo do
    let(:pipeline_info) do
      PipelineWatcher::Data::PipelineInfo.new(
        name: 'test-pipeline',
        status: 'InProgress',
        current_step: 'Build:BuildAction',
        started_at: Time.now - 3600, # 1 hour ago
        commit_hash: 'abcdef1234567890',
        commit_message: 'Add new feature'
      )
    end

    describe '#initialize' do
      it 'creates a pipeline info object with all attributes' do
        expect(pipeline_info.name).to eq('test-pipeline')
        expect(pipeline_info.status).to eq('InProgress')
        expect(pipeline_info.current_step).to eq('Build:BuildAction')
        expect(pipeline_info.commit_hash).to eq('abcdef1234567890')
        expect(pipeline_info.commit_message).to eq('Add new feature')
      end

      it 'has default values for optional attributes' do
        minimal_pipeline = PipelineWatcher::Data::PipelineInfo.new(name: 'minimal')
        expect(minimal_pipeline.status).to eq('Unknown')
        expect(minimal_pipeline.error_details).to eq([])
      end
    end

    describe '#failed?' do
      it 'returns true when status is Failed' do
        pipeline_info.status = 'Failed'
        expect(pipeline_info.failed?).to be true
      end

      it 'returns false when status is not Failed' do
        expect(pipeline_info.failed?).to be false
      end
    end

    describe '#in_progress?' do
      it 'returns true when status is InProgress' do
        expect(pipeline_info.in_progress?).to be true
      end

      it 'returns false when status is not InProgress' do
        pipeline_info.status = 'Succeeded'
        expect(pipeline_info.in_progress?).to be false
      end
    end

    describe '#succeeded?' do
      it 'returns true when status is Succeeded' do
        pipeline_info.status = 'Succeeded'
        expect(pipeline_info.succeeded?).to be true
      end

      it 'returns false when status is not Succeeded' do
        expect(pipeline_info.succeeded?).to be false
      end
    end

    describe '#short_commit_hash' do
      it 'returns first 8 characters for long hashes' do
        expect(pipeline_info.short_commit_hash).to eq('abcdef12')
      end

      it 'returns full hash for short hashes' do
        pipeline_info.commit_hash = 'abc123'
        expect(pipeline_info.short_commit_hash).to eq('abc123')
      end

      it 'returns N/A when no commit hash' do
        pipeline_info.commit_hash = nil
        expect(pipeline_info.short_commit_hash).to eq('N/A')
      end
    end

    describe '#display_commit' do
      it 'returns hash and message when both available' do
        expect(pipeline_info.display_commit).to eq('abcdef12: Add new feature')
      end

      it 'returns only hash when no message' do
        pipeline_info.commit_message = nil
        expect(pipeline_info.display_commit).to eq('abcdef12')
      end

      it 'returns N/A when no commit hash' do
        pipeline_info.commit_hash = nil
        expect(pipeline_info.display_commit).to eq('N/A')
      end
    end
  end

  describe PipelineWatcher::Data::BuildInfo do
    let(:build_info) do
      PipelineWatcher::Data::BuildInfo.new(
        name: 'test-build',
        status: 'IN_PROGRESS',
        current_phase: 'BUILD',
        started_at: Time.now - 1800, # 30 minutes ago
        commit_hash: 'xyz789'
      )
    end

    describe '#initialize' do
      it 'creates a build info object with all attributes' do
        expect(build_info.name).to eq('test-build')
        expect(build_info.status).to eq('IN_PROGRESS')
        expect(build_info.current_phase).to eq('BUILD')
        expect(build_info.commit_hash).to eq('xyz789')
      end
    end

    describe '#failed?' do
      it 'returns true when status is FAILED' do
        build_info.status = 'FAILED'
        expect(build_info.failed?).to be true
      end

      it 'returns false when status is not FAILED' do
        expect(build_info.failed?).to be false
      end
    end

    describe '#in_progress?' do
      it 'returns true when status is IN_PROGRESS' do
        expect(build_info.in_progress?).to be true
      end

      it 'returns false when status is not IN_PROGRESS' do
        build_info.status = 'SUCCEEDED'
        expect(build_info.in_progress?).to be false
      end
    end

    describe '#succeeded?' do
      it 'returns true when status is SUCCEEDED' do
        build_info.status = 'SUCCEEDED'
        expect(build_info.succeeded?).to be true
      end

      it 'returns false when status is not SUCCEEDED' do
        expect(build_info.succeeded?).to be false
      end
    end
  end

  describe PipelineWatcher::Data::MonitoringData do
    let(:monitoring_data) { PipelineWatcher::Data::MonitoringData.new }
    let(:pipeline) { PipelineWatcher::Data::PipelineInfo.new(name: 'test-pipeline') }
    let(:build) { PipelineWatcher::Data::BuildInfo.new(name: 'test-build') }

    describe '#initialize' do
      it 'creates empty arrays for pipelines and builds' do
        expect(monitoring_data.pipelines).to eq([])
        expect(monitoring_data.builds).to eq([])
        expect(monitoring_data.last_updated).to be_a(Time)
      end
    end

    describe '#add_pipeline' do
      it 'adds a pipeline to the collection' do
        monitoring_data.add_pipeline(pipeline)
        expect(monitoring_data.pipelines).to include(pipeline)
      end

      it 'updates the timestamp' do
        old_time = monitoring_data.last_updated
        sleep(0.01) # Small delay to ensure time difference
        monitoring_data.add_pipeline(pipeline)
        expect(monitoring_data.last_updated).to be > old_time
      end
    end

    describe '#add_build' do
      it 'adds a build to the collection' do
        monitoring_data.add_build(build)
        expect(monitoring_data.builds).to include(build)
      end
    end

    describe '#total_items' do
      it 'returns the total count of pipelines and builds' do
        monitoring_data.add_pipeline(pipeline)
        monitoring_data.add_build(build)
        expect(monitoring_data.total_items).to eq(2)
      end
    end

    describe '#has_failures?' do
      it 'returns true when there are failed pipelines' do
        failed_pipeline = PipelineWatcher::Data::PipelineInfo.new(name: 'failed', status: 'Failed')
        monitoring_data.add_pipeline(failed_pipeline)
        expect(monitoring_data.has_failures?).to be true
      end

      it 'returns true when there are failed builds' do
        failed_build = PipelineWatcher::Data::BuildInfo.new(name: 'failed', status: 'FAILED')
        monitoring_data.add_build(failed_build)
        expect(monitoring_data.has_failures?).to be true
      end

      it 'returns false when no failures' do
        success_pipeline = PipelineWatcher::Data::PipelineInfo.new(name: 'success', status: 'Succeeded')
        monitoring_data.add_pipeline(success_pipeline)
        expect(monitoring_data.has_failures?).to be false
      end
    end

    describe '#has_in_progress?' do
      it 'returns true when there are in-progress pipelines' do
        in_progress_pipeline = PipelineWatcher::Data::PipelineInfo.new(name: 'running', status: 'InProgress')
        monitoring_data.add_pipeline(in_progress_pipeline)
        expect(monitoring_data.has_in_progress?).to be true
      end

      it 'returns true when there are in-progress builds' do
        in_progress_build = PipelineWatcher::Data::BuildInfo.new(name: 'building', status: 'IN_PROGRESS')
        monitoring_data.add_build(in_progress_build)
        expect(monitoring_data.has_in_progress?).to be true
      end

      it 'returns false when nothing is in progress' do
        success_pipeline = PipelineWatcher::Data::PipelineInfo.new(name: 'done', status: 'Succeeded')
        monitoring_data.add_pipeline(success_pipeline)
        expect(monitoring_data.has_in_progress?).to be false
      end
    end

    describe '#update_pipeline' do
      it 'updates a pipeline by name' do
        monitoring_data.add_pipeline(pipeline)

        monitoring_data.update_pipeline('test-pipeline') do |p|
          p.status = 'Succeeded'
        end

        expect(pipeline.status).to eq('Succeeded')
      end

      it 'does nothing for non-existent pipeline' do
        expect {
          monitoring_data.update_pipeline('non-existent') { |p| p.status = 'Failed' }
        }.not_to raise_error
      end
    end

    describe '#update_build' do
      it 'updates a build by name' do
        monitoring_data.add_build(build)

        monitoring_data.update_build('test-build') do |b|
          b.status = 'SUCCEEDED'
        end

        expect(build.status).to eq('SUCCEEDED')
      end
    end
  end
end
