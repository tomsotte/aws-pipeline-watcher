# frozen_string_literal: true

require 'thor'
require 'yaml'
require 'aws-sdk-codepipeline'
require 'aws-sdk-codebuild'
require 'aws-sdk-sts'
require 'cli/ui'
require 'time'
require 'json'
require 'open3'
require 'fileutils'

require_relative 'pipeline_watcher/version'
require_relative 'pipeline_watcher/utils/time_formatter'
require_relative 'pipeline_watcher/data/models'
require_relative 'pipeline_watcher/config/manager'
require_relative 'pipeline_watcher/services/pipeline_service'
require_relative 'pipeline_watcher/services/build_service'
require_relative 'pipeline_watcher/ui/components'
require_relative 'pipeline_watcher/ui/renderer'
require_relative 'pipeline_watcher/watcher'
require_relative 'pipeline_watcher/cli'

module PipelineWatcher
  # Main module for AWS Pipeline Watcher
  #
  # This is a simplified architecture designed to be beginner-friendly:
  #
  # ## Architecture Overview:
  #
  # ### Data Layer (`data/`)
  # - `models.rb` - Simple data structures for pipelines and builds
  #
  # ### Configuration (`config/`)
  # - `manager.rb` - Handles loading, saving, and validating configuration
  #
  # ### Services (`services/`)
  # - `pipeline_service.rb` - Fetches AWS CodePipeline data
  # - `build_service.rb` - Fetches AWS CodeBuild data
  #
  # ### UI Layer (`ui/`)
  # - `components.rb` - Reusable UI components using CLI-UI
  # - `renderer.rb` - Main display orchestrator
  #
  # ### Core Classes
  # - `watcher.rb` - Main orchestrator that ties everything together
  # - `cli.rb` - Command-line interface
  #
  # ### Utilities (`utils/`)
  # - `time_formatter.rb` - Time formatting utilities
  #
  # ## For Beginners:
  #
  # ### To modify the UI:
  # 1. Edit `ui/components.rb` to change individual UI elements
  # 2. Edit `ui/renderer.rb` to change the overall layout
  #
  # ### To add new AWS services:
  # 1. Create a new service in `services/` (follow the pattern of existing services)
  # 2. Add a new data model in `data/models.rb`
  # 3. Update `watcher.rb` to use the new service
  # 4. Update `ui/renderer.rb` to display the new data
  #
  # ### To modify configuration:
  # 1. Edit `config/manager.rb` to add new config options
  # 2. Update `cli.rb` to collect the new configuration from users
  #
  # ### To change timing or behavior:
  # 1. Edit `watcher.rb` - this is the main control loop

  class Error < StandardError; end
end
