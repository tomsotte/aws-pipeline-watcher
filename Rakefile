# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'fileutils'
require 'digest'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

desc 'Run tests'
task test: :spec

desc 'Run RuboCop'
task lint: :rubocop

desc 'Run all checks (tests + linting)'
task check: %i[test lint]

desc 'Install dependencies'
task :install do
  sh 'bundle install'
end

desc 'Test local Homebrew installation'
task :brew_local do
  require_relative 'lib/pipeline_watcher/version'

  version = PipelineWatcher::VERSION
  cache_name = "aws-pipeline-watcher-#{version}"
  tarball_name = "#{cache_name}.tar.gz"

  # Clean up previous builds
  sh 'rm -f *.gem *.tar.gz .tarball_info'

  sh "git archive --format=tar.gz -o #{tarball_name} HEAD"

  sha256 = Digest::SHA256.file(tarball_name).hexdigest

  # Calculate SHA256 and update formula
  formula_path = File.join(Dir.pwd, 'Formula', 'aws-pipeline-watcher.rb')
  formula_content = File.read(formula_path)
  formula_content.gsub!(/url ".*"/, "url \"https://github.com/tomsotte/aws-pipeline-watcher/archive/#{tarball_name}\"")
  formula_content.gsub!(/sha256 ".*"/, "sha256 \"#{sha256}\"")
  File.write(formula_path, formula_content)
  puts "Updated formula with\n  SHA256: #{sha256} and\n  tar: #{tarball_name}"

  # Copy to Homebrew cache
  system("mv #{tarball_name} $(brew --cache --build-from-source --formula #{formula_path})")

  system('brew uninstall aws-pipeline-watcher')

  system("brew install --formula #{formula_path}")
end

desc 'Clean up build artifacts'
task :clean do
  sh 'rm -f *.gem *.tar.gz .tarball_info'
end

task default: :check
