class AwsPipelineWatcher < Formula
  desc "Ruby CLI tool for monitoring AWS CodePipeline and CodeBuild statuses"
  homepage "https://github.com/your-username/aws-pipeline-watcher"
  url "https://github.com/tomsotte/aws-pipeline-watcher/archive/v1.0.0.tar.gz"
  sha256 "4abcc8c56c85d703890a51d2ce6ccea1372a30c10c5ec63da4af6a68736f7135"
  license "MIT"

  depends_on "ruby"

  def install
    ENV["GEM_HOME"] = libexec

    system "gem", "install", "bundler", "--no-document"
    system "bundle", "config", "set", "path", libexec
    system "bundle", "install", "--without", "development", "test"

    libexec.install Dir["*"]

    (bin/"aws-pipeline-watcher").write_env_script libexec/"bin/aws-pipeline-watcher",
                                                  GEM_HOME: ENV["GEM_HOME"],
                                                  GEM_PATH: libexec,
                                                  BUNDLE_GEMFILE: libexec/"Gemfile"
  end

  test do
    assert_match "Commands:", shell_output("#{bin}/aws-pipeline-watcher help")
    output = shell_output("#{bin}/aws-pipeline-watcher watch 2>&1", 1)
    assert_match "Configuration missing", output
  end
end
