class AwsPipelineWatcher < Formula
  desc "Ruby CLI tool for monitoring AWS CodePipeline and CodeBuild statuses"
  homepage "https://github.com/tomsotte/aws-pipeline-watcher"
  url "https://github.com/tomsotte/aws-pipeline-watcher/archive/aws-pipeline-watcher-1.0.2.tar.gz"
  sha256 "0d976e00fdfa61710c6c936eb3e8fc738dac8f388a1e7d6961e16735dea46426"
  license "MIT"

  depends_on "ruby"

  def install
    ENV["GEM_HOME"] = libexec

    system "bundle", "install", "--without", "development"

    system "gem", "build", "aws-pipeline-watcher.gemspec"
    system "gem", "install", "--ignore-dependencies", "aws-pipeline-watcher-#{version}.gem"

    bin.install libexec/"bin/aws-pipeline-watcher"
    bin.env_script_all_files(libexec/"bin", GEM_HOME: ENV.fetch("GEM_HOME", nil))
  end

  test do
    assert_match "Commands:", shell_output("#{bin}/aws-pipeline-watcher help")
  end
end
