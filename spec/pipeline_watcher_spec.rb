# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/pipeline_watcher'

RSpec.describe PipelineWatcher do
  it 'has a version number' do
    expect(PipelineWatcher::VERSION).not_to be nil
  end
end

RSpec.describe PipelineWatcher::Config::Manager do
  let(:test_config_dir) { File.expand_path('~/.config/aws-pipeline-watcher-test') }
  let(:test_config_file) { File.join(test_config_dir, 'config.yml') }

  before do
    # Stub the config directory and files for testing
    stub_const('PipelineWatcher::Config::Manager::CONFIG_DIR', test_config_dir)
    stub_const('PipelineWatcher::Config::Manager::CONFIG_FILE', test_config_file)
  end

  after do
    FileUtils.rm_rf(test_config_dir) if Dir.exist?(test_config_dir)
  end

  describe '#load_config' do
    context 'when config file exists' do
      let(:config_data) do
        {
          'use_aws_cli' => true,
          'aws_region' => 'us-west-2',
          'aws_account_id' => '123456789012',
          'pipeline_names' => ['test-pipeline'],
          'codebuild_project_names' => ['test-build']
        }
      end

      before do
        FileUtils.mkdir_p(test_config_dir)
        File.write(test_config_file, config_data.to_yaml)
      end

      it 'loads the configuration from file' do
        manager = PipelineWatcher::Config::Manager.new
        expect(manager.get('use_aws_cli')).to be true
        expect(manager.get('aws_region')).to eq('us-west-2')
        expect(manager.pipeline_names).to eq(['test-pipeline'])
      end
    end

    context 'when config file does not exist' do
      it 'returns default configuration' do
        manager = PipelineWatcher::Config::Manager.new
        expect(manager.get('use_aws_cli')).to be true
        expect(manager.get('aws_region')).to eq('us-east-1')
        expect(manager.pipeline_names).to eq([])
      end
    end

    context 'when config file is corrupted' do
      before do
        FileUtils.mkdir_p(test_config_dir)
        File.write(test_config_file, 'invalid: yaml: content: [')
      end

      it 'returns default configuration' do
        manager = PipelineWatcher::Config::Manager.new
        expect(manager.get('use_aws_cli')).to be true
        expect(manager.get('aws_region')).to eq('us-east-1')
      end
    end
  end

  describe '#valid?' do
    let(:manager) { PipelineWatcher::Config::Manager.new }

    context 'with valid manual configuration' do
      let(:valid_config) do
        {
          'aws_access_key_id' => 'test_key',
          'aws_secret_access_key' => 'test_secret',
          'aws_region' => 'us-east-1',
          'aws_account_id' => '123456789012',
          'pipeline_names' => ['test-pipeline'],
          'use_aws_cli' => false
        }
      end

      it 'returns true' do
        manager.update(valid_config)
        expect(manager.valid?).to be true
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
        manager.update(valid_cli_config)
        expect(manager.valid?).to be true
      end
    end

    context 'with missing aws_access_key_id for manual config' do
      let(:invalid_config) do
        {
          'aws_secret_access_key' => 'test_secret',
          'aws_region' => 'us-east-1',
          'aws_account_id' => '123456789012',
          'pipeline_names' => ['test-pipeline'],
          'use_aws_cli' => false
        }
      end

      it 'returns false' do
        manager.update(invalid_config)
        expect(manager.valid?).to be false
      end
    end

    context 'with missing aws_region for CLI config' do
      let(:invalid_config) do
        {
          'aws_region' => nil,
          'aws_account_id' => '123456789012',
          'pipeline_names' => ['test-pipeline'],
          'use_aws_cli' => true
        }
      end

      it 'returns false' do
        manager.update(invalid_config)
        expect(manager.valid?).to be false
      end
    end

    context 'with empty pipeline_names and codebuild_project_names' do
      let(:invalid_config) do
        {
          'aws_access_key_id' => 'test_key',
          'aws_secret_access_key' => 'test_secret',
          'aws_region' => 'us-east-1',
          'aws_account_id' => '123456789012',
          'pipeline_names' => [],
          'codebuild_project_names' => [],
          'use_aws_cli' => false
        }
      end

      it 'returns false' do
        manager.update(invalid_config)
        expect(manager.valid?).to be false
      end
    end

    context 'with nil pipeline_names but valid codebuild_project_names' do
      let(:valid_config) do
        {
          'aws_access_key_id' => 'test_key',
          'aws_secret_access_key' => 'test_secret',
          'aws_region' => 'us-east-1',
          'aws_account_id' => '123456789012',
          'pipeline_names' => nil,
          'codebuild_project_names' => ['test-build'],
          'use_aws_cli' => false
        }
      end

      it 'returns true' do
        manager.update(valid_config)
        expect(manager.valid?).to be true
      end
    end
  end

  describe '#summary' do
    let(:manager) { PipelineWatcher::Config::Manager.new }

    it 'provides a readable configuration summary' do
      config = {
        'use_aws_cli' => true,
        'aws_region' => 'us-west-2',
        'aws_profile' => 'production',
        'aws_account_id' => '123456789012',
        'pipeline_names' => ['app-pipeline', 'api-pipeline'],
        'codebuild_project_names' => ['app-build']
      }
      manager.update(config)

      summary = manager.summary
      expect(summary).to include('AWS Mode: CLI')
      expect(summary).to include('Region: us-west-2')
      expect(summary).to include('Profile: production')
      expect(summary).to include('Account ID: 123456789012')
      expect(summary).to include('Pipelines: app-pipeline, api-pipeline')
      expect(summary).to include('Builds: app-build')
    end
  end
end

RSpec.describe PipelineWatcher::Watcher do
  let(:watcher) { PipelineWatcher::Watcher.new }

  describe '#initialize' do
    it 'creates a watcher with all required components' do
      expect(watcher.config).to be_a(PipelineWatcher::Config::Manager)
      expect(watcher.renderer).to be_a(PipelineWatcher::UI::Renderer)
      expect(watcher.monitoring_data).to be_a(PipelineWatcher::Data::MonitoringData)
    end
  end

  describe 'error handling' do
    it 'handles interrupt signals gracefully' do
      expect { watcher.send(:shutdown_gracefully) }.to raise_error(SystemExit)
    end

    it 'identifies credential errors correctly' do
      credential_error_messages = [
        'token expired',
        'credential invalid',
        'access denied',
        'unauthorized'
      ]

      credential_error_messages.each do |message|
        expect(watcher.send(:credential_error?, message)).to be true
      end
    end

    it 'does not identify non-credential errors as credential errors' do
      non_credential_errors = [
        'network timeout',
        'service unavailable',
        'invalid parameter'
      ]

      non_credential_errors.each do |message|
        expect(watcher.send(:credential_error?, message)).to be false
      end
    end
  end
end
