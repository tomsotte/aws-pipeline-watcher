# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PipelineWatcher::Services::BuildService do
  let(:config_manager) { double('ConfigManager') }
  let(:build_service) { described_class.new(config_manager) }

  before do
    allow(config_manager).to receive(:aws_region).and_return('us-east-1')
    allow(config_manager).to receive(:using_aws_cli?).and_return(true)
    allow(config_manager).to receive(:aws_profile).and_return('default')
  end

  describe '#extract_commit_info' do
    it 'extracts commit hash from resolved_source_version' do
      build = double('Build',
        resolved_source_version: 'abc123def456',
        source_version: nil
      )

      result = build_service.send(:extract_commit_info, build)
      expect(result[:hash]).to eq('abc123def456')
      expect(result[:message]).to be_nil
    end

    it 'falls back to source_version when resolved_source_version is nil' do
      build = double('Build',
        resolved_source_version: nil,
        source_version: 'fallback123'
      )

      result = build_service.send(:extract_commit_info, build)
      expect(result[:hash]).to eq('fallback123')
      expect(result[:message]).to be_nil
    end

    it 'returns nil values when no commit info is available' do
      build = double('Build',
        resolved_source_version: nil,
        source_version: nil
      )

      result = build_service.send(:extract_commit_info, build)
      expect(result[:hash]).to be_nil
      expect(result[:message]).to be_nil
    end
  end
end
