# frozen_string_literal: true

require_relative 'lib/pipeline_watcher/version'

Gem::Specification.new do |spec|
  spec.name = 'aws-pipeline-watcher'
  spec.version = PipelineWatcher::VERSION
  spec.authors = ['Tommaso Sotte']
  spec.email = ['tommaso.sotte@gmail.com']

  spec.summary = 'A Ruby CLI tool for monitoring AWS CodePipeline statuses'
  spec.description = 'AWS Pipeline Watcher provides live updates showing the status of AWS CodePipelines with real-time monitoring and configuration management.'
  spec.homepage = 'https://github.com/tomsotte/aws-pipeline-watcher'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata = { "source_code_uri" => "https://github.com/tomsotte/aws-pipeline-watcher" }

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = 'bin'
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'aws-sdk-codepipeline', '~> 1.0'
  spec.add_dependency 'aws-sdk-sso', '~> 1.0'
  spec.add_dependency 'aws-sdk-ssooidc', '~> 1.0'
  spec.add_dependency 'aws-sdk-sts', '~> 1.0'
  spec.add_dependency 'colorize', '~> 0.8'
  spec.add_dependency 'rexml', '~> 3.0'
  spec.add_dependency 'thor', '~> 1.0'

  # Development dependencies
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.60'
end
