# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'fileutils'

RSpec.describe PipelineWatcher::CLI do
  let(:test_config_file) { File.expand_path('~/.pipeline_watcher_config_test.yml') }

  before do
    # Stub the CONFIG_FILE constant to use a test file
    stub_const('PipelineWatcher::CLI::CONFIG_FILE', test_config_file)
  end

  after do
    File.delete(test_config_file) if File.exist?(test_config_file)
  end

  describe '#load_config' do
    context 'when config file exists' do
      let(:config_data) do
        {
          'aws_access_key_id' => 'test_key',
          'aws_secret_access_key' => 'test_secret',
          'aws_region' => 'us-west-2',
          'aws_account_id' => '123456789012',
          'pipeline_names' => %w[test-pipeline-1 test-pipeline-2]
        }
      end

      before do
        File.write(test_config_file, config_data.to_yaml)
      end

      it 'loads the configuration from file' do
        cli = PipelineWatcher::CLI.new
        config = cli.send(:load_config)

        expect(config).to eq(config_data)
      end
    end

    context 'when config file does not exist' do
      it 'returns empty hash' do
        cli = PipelineWatcher::CLI.new
        config = cli.send(:load_config)

        expect(config).to eq({})
      end
    end

    context 'when config file is corrupted' do
      before do
        File.write(test_config_file, 'invalid: yaml: content: [')
      end

      it 'returns empty hash' do
        cli = PipelineWatcher::CLI.new
        config = cli.send(:load_config)

        expect(config).to eq({})
      end
    end
  end

  describe '#config_valid?' do
    let(:cli) { PipelineWatcher::CLI.new }

    context 'with valid manual configuration' do
      let(:valid_config) do
        {
          'aws_access_key_id' => 'test_key',
          'aws_secret_access_key' => 'test_secret',
          'aws_account_id' => '123456789012',
          'pipeline_names' => ['test-pipeline'],
          'use_aws_cli' => false
        }
      end

      it 'returns true' do
        expect(cli.send(:config_valid?, valid_config)).to be true
      end
    end

    context 'with valid AWS CLI configuration' do
      let(:valid_cli_config) do
        {
          'aws_region' => 'us-east-1',
          'aws_account_id' => '123456789012',
          'pipeline_names' => ['test-pipeline'],
          'use_aws_cli' => true
        }
      end

      it 'returns true' do
        expect(cli.send(:config_valid?, valid_cli_config)).to be true
      end
    end

    context 'with missing aws_access_key_id for manual config' do
      let(:invalid_config) do
        {
          'aws_secret_access_key' => 'test_secret',
          'aws_account_id' => '123456789012',
          'pipeline_names' => ['test-pipeline'],
          'use_aws_cli' => false
        }
      end

      it 'returns false' do
        expect(cli.send(:config_valid?, invalid_config)).to be false
      end
    end

    context 'with missing aws_region for CLI config' do
      let(:invalid_cli_config) do
        {
          'aws_account_id' => '123456789012',
          'pipeline_names' => ['test-pipeline'],
          'use_aws_cli' => true
        }
      end

      it 'returns false' do
        expect(cli.send(:config_valid?, invalid_cli_config)).to be false
      end
    end

    context 'with empty pipeline_names' do
      let(:invalid_config) do
        {
          'aws_access_key_id' => 'test_key',
          'aws_secret_access_key' => 'test_secret',
          'aws_account_id' => '123456789012',
          'pipeline_names' => [],
          'use_aws_cli' => false
        }
      end

      it 'returns false' do
        expect(cli.send(:config_valid?, invalid_config)).to be false
      end
    end

    context 'with nil pipeline_names' do
      let(:invalid_config) do
        {
          'aws_access_key_id' => 'test_key',
          'aws_secret_access_key' => 'test_secret',
          'aws_account_id' => '123456789012',
          'pipeline_names' => nil,
          'use_aws_cli' => false
        }
      end

      it 'returns false' do
        expect(cli.send(:config_valid?, invalid_config)).to be false
      end
    end
  end

  describe '#detect_aws_cli_config' do
    let(:cli) { PipelineWatcher::CLI.new }

    context 'when AWS CLI is available and configured' do
      before do
        allow(Open3).to receive(:capture3).with('aws configure list').and_return(['', '', double(success?: true)])
        allow(Open3).to receive(:capture3).with('aws configure get region').and_return(['us-west-2', '', double(success?: true)])
        allow(Open3).to receive(:capture3).with('aws configure get profile').and_return(['', '', double(success?: true)])
        allow(Open3).to receive(:capture3).with('aws sts get-caller-identity --query Account --output text').and_return(['123456789012', '', double(success?: true)])
      end

      it 'detects AWS CLI configuration' do
        result = cli.send(:detect_aws_cli_config)
        expect(result[:detected]).to be true
        expect(result[:region]).to eq('us-west-2')
        expect(result[:account_id]).to eq('123456789012')
        expect(result[:profile]).to eq('default')
      end
    end

    context 'when AWS CLI is not available' do
      before do
        allow(Open3).to receive(:capture3).and_raise(StandardError.new('AWS CLI not found'))
      end

      it 'returns undetected configuration' do
        result = cli.send(:detect_aws_cli_config)
        expect(result[:detected]).to be false
      end
    end
  end
end

RSpec.describe PipelineWatcher::PipelineStatusWatcher do
  let(:config) do
    {
      'aws_access_key_id' => 'test_key',
      'aws_secret_access_key' => 'test_secret',
      'aws_region' => 'us-east-1',
      'aws_account_id' => '123456789012',
      'pipeline_names' => ['test-pipeline'],
      'use_aws_cli' => false
    }
  end

  let(:cli_config) do
    {
      'aws_region' => 'us-east-1',
      'aws_account_id' => '123456789012',
      'aws_profile' => 'default',
      'pipeline_names' => ['test-pipeline'],
      'use_aws_cli' => true
    }
  end

  describe '#initialize' do
    it 'creates a new watcher with manual credentials config' do
      # Mock AWS client creation to avoid actual AWS calls
      allow(Aws::CodePipeline::Client).to receive(:new).and_return(double('client'))

      watcher = PipelineWatcher::PipelineStatusWatcher.new(config)
      expect(watcher).to be_instance_of(PipelineWatcher::PipelineStatusWatcher)
    end

    it 'creates a new watcher with AWS CLI config' do
      # Mock AWS client creation to avoid actual AWS calls
      allow(Aws::CodePipeline::Client).to receive(:new).and_return(double('client'))

      watcher = PipelineWatcher::PipelineStatusWatcher.new(cli_config)
      expect(watcher).to be_instance_of(PipelineWatcher::PipelineStatusWatcher)
    end
  end

  describe '#format_duration' do
    let(:watcher) do
      allow(Aws::CodePipeline::Client).to receive(:new).and_return(double('client'))
      PipelineWatcher::PipelineStatusWatcher.new(config)
    end

    it 'formats seconds only' do
      expect(watcher.send(:format_duration, 45)).to eq('45s')
    end

    it 'formats minutes and seconds' do
      expect(watcher.send(:format_duration, 125)).to eq('2m 5s')
    end

    it 'formats hours, minutes and seconds' do
      expect(watcher.send(:format_duration, 3665)).to eq('1h 1m 5s')
    end
  end

  describe '#calculate_timer' do
    let(:watcher) do
      allow(Aws::CodePipeline::Client).to receive(:new).and_return(double('client'))
      PipelineWatcher::PipelineStatusWatcher.new(config)
    end

    let(:started_at) { Time.now - 3600 } # 1 hour ago

    it 'calculates timer for InProgress status' do
      result = watcher.send(:calculate_timer, started_at, 'InProgress')
      expect(result).to match(/1h 0m \d+s \(running\)/)
    end

    it 'calculates timer for Succeeded status' do
      result = watcher.send(:calculate_timer, started_at, 'Succeeded')
      expect(result).to match(/1h 0m \d+s \(completed\)/)
    end

    it 'returns N/A for nil started_at' do
      result = watcher.send(:calculate_timer, nil, 'InProgress')
      expect(result).to eq('N/A')
    end
  end

  describe '#get_source_revision' do
    let(:watcher) do
      allow(Aws::CodePipeline::Client).to receive(:new).and_return(double('client'))
      PipelineWatcher::PipelineStatusWatcher.new(config)
    end

    it 'returns shortened revision ID' do
      execution = double('execution')
      source_revision = double('source_revision', revision_id: 'abcdef1234567890')
      allow(execution).to receive(:source_revisions).and_return([source_revision])

      result = watcher.send(:get_source_revision, execution)
      expect(result).to eq('abcdef12')
    end

    it 'returns full revision if shorter than 8 characters' do
      execution = double('execution')
      source_revision = double('source_revision', revision_id: 'abc123')
      allow(execution).to receive(:source_revisions).and_return([source_revision])

      result = watcher.send(:get_source_revision, execution)
      expect(result).to eq('abc123')
    end

    it 'returns N/A if no source revisions' do
      execution = double('execution')
      allow(execution).to receive(:source_revisions).and_return([])

      result = watcher.send(:get_source_revision, execution)
      expect(result).to eq('N/A')
    end

    it 'returns N/A if source_revisions is nil' do
      execution = double('execution')
      allow(execution).to receive(:source_revisions).and_return(nil)

      result = watcher.send(:get_source_revision, execution)
      expect(result).to eq('N/A')
    end
  end
end
