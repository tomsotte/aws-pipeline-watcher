# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

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

desc 'Build and install gem locally'
task :install_gem do
  sh 'gem build pipeline_watcher.gemspec'
  sh 'gem install pipeline_watcher-*.gem'
end

desc 'Clean up build artifacts'
task :clean do
  sh 'rm -f *.gem'
end

desc 'Show help'
task :help do
  puts 'Available tasks:'
  puts '  rake install      - Install dependencies'
  puts '  rake test         - Run tests'
  puts '  rake lint         - Run RuboCop linting'
  puts '  rake check        - Run all checks (tests + linting)'
  puts '  rake install_gem  - Build and install gem locally'
  puts '  rake clean        - Clean up build artifacts'
  puts '  rake build        - Build gem (from bundler/gem_tasks)'
  puts '  rake release      - Release gem (from bundler/gem_tasks)'
end

task default: :check
