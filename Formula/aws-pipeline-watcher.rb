class AwsPipelineWatcher < Formula
  desc "Ruby CLI tool for monitoring AWS CodePipeline and CodeBuild statuses"
  homepage "https://github.com/tomsotte/aws-pipeline-watcher"
  url "https://github.com/tomsotte/aws-pipeline-watcher/archive/v1.0.0.tar.gz"
  sha256 "4abcc8c56c85d703890a51d2ce6ccea1372a30c10c5ec63da4af6a68736f7135"
  license "MIT"

  depends_on "ruby"

  def install
    ENV["GEM_HOME"] = libexec
    ENV["GEM_PATH"] = libexec
    ENV["BUNDLE_GEMFILE"] = buildpath/"Gemfile"

    # Install bundler and gems
    system "gem", "install", "bundler", "--no-document"
    system "bundle", "config", "set", "path", libexec
    system "bundle", "install", "--without", "development", "test"

    # Install all files to libexec
    libexec.install Dir["*"]

    # Create wrapper script
    (bin/"aws-pipeline-watcher").write <<~EOS
      #!/bin/bash
      export GEM_HOME="#{libexec}"
      export GEM_PATH="#{libexec}"
      export BUNDLE_GEMFILE="#{libexec}/Gemfile"
      cd "#{libexec}"
      exec bundle exec ruby "#{libexec}/bin/aws-pipeline-watcher" "$@"
    EOS

    # Make wrapper executable
    chmod 0755, bin/"aws-pipeline-watcher"
  end

  test do
    assert_match "Commands:", shell_output("#{bin}/aws-pipeline-watcher help")
    output = shell_output("#{bin}/aws-pipeline-watcher watch 2>&1", 1)
    assert_match "Configuration missing", output
  end
end
