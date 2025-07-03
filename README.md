# AWS Pipeline Watcher

> Disclaimer: this project was made entirely with GitHub Copilot agent. No other human developer has been exploited.

A Ruby CLI tool that provides live updates showing the status of AWS CodePipelines and CodeBuild projects with real-time monitoring and colorful output.

## Features

- 🔄 **Real-time monitoring** - Updates every 5 seconds with steady, flicker-free UI
- 🎯 **Accurate status display** - Intelligent status detection that shows true pipeline and build state
- 🚨 **Error details for failures** - Failed pipelines and builds show 2-3 lines of actionable error information
- 🔐 **AWS SSO support** - Automatic token refresh for AWS SSO users
- 🎨 **Color-coded status** - Easy to identify pipeline and build states at a glance
- ⚙️ **Easy configuration** - Simple setup with standard config paths (XDG compliant)
- 📊 **Detailed information** - Shows execution status, source revision, timing, and current steps/phases
- 🔧 **Multiple service support** - Monitor several pipelines and CodeBuild projects simultaneously
- 🖥️ **Smooth UI** - In-place updates without screen flickering or blinking
- 🏗️ **CodeBuild integration** - Full support for AWS CodeBuild projects alongside CodePipelines

## Prerequisites

- Ruby 3.0.0 or higher
- AWS account with CodePipeline and/or CodeBuild access
- AWS CLI configured (recommended) OR AWS credentials (Access Key ID and Secret Access Key)

## Installation

### 🍺 Homebrew (Recommended)

```bash
# Add the tap
brew tap your-username/aws-pipeline-watcher

# Install the tool
brew install aws-pipeline-watcher
```

Or install directly:
```bash
brew install https://raw.githubusercontent.com/your-username/aws-pipeline-watcher/main/Formula/aws-pipeline-watcher.rb
```

### 📦 Manual Installation

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd aws-pipeline-watcher
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Make the executable runnable:
   ```bash
   chmod +x bin/aws-pipeline-watcher
   ```

4. Create system-wide link:
   ```bash
   sudo ln -s $(pwd)/bin/aws-pipeline-watcher /usr/local/bin/aws-pipeline-watcher
   ```

## Configuration

Run the configuration command to set up your AWS credentials and specify pipelines to monitor:

```bash
./bin/aws-pipeline-watcher config
```

The tool will automatically detect your AWS CLI configuration if available. You'll be prompted for:

**Option A: Use AWS CLI (Recommended)**
- The tool will auto-detect your AWS CLI configuration
- Just confirm to use AWS CLI credentials when prompted
- Region and Account ID will be detected automatically

**Option B: Manual Credentials**
- **AWS Access Key ID**: Your AWS access key
- **AWS Secret Access Key**: Your AWS secret key
- **AWS Region**: The AWS region where your pipelines are located (default: us-east-1)
- **AWS Account ID**: Your AWS account ID (12-digit number)

**For both options:**
- **Pipeline names**: Comma-separated list of pipeline names to monitor
- **CodeBuild project names**: Comma-separated list of CodeBuild project names to monitor

### Configuration File

Settings are stored in the standard configuration directory:
- **macOS/Linux**: `~/.config/aws-pipeline-watcher/config.yml`
- **Windows**: `%APPDATA%\aws-pipeline-watcher\config.yml`

**Using AWS CLI with SSO (Recommended):**
```yaml
use_aws_cli: true
aws_profile: default
aws_region: us-east-1
aws_account_id: "123456789012"
pipeline_names:
  - my-pipeline-1
  - my-pipeline-2
codebuild_project_names:
  - my-build-project-1
  - my-build-project-2
```

**Using Manual Credentials:**
```yaml
use_aws_cli: false
aws_access_key_id: YOUR_ACCESS_KEY
aws_secret_access_key: YOUR_SECRET_KEY
aws_region: us-east-1
aws_account_id: "123456789012"
pipeline_names:
  - my-pipeline-1
  - my-pipeline-2
codebuild_project_names:
  - my-build-project-1
  - my-build-project-2
```

### AWS SSO Token Management

For AWS SSO users, the tool automatically:
- **Detects expired tokens** during monitoring
- **Refreshes credentials** using `aws sso login`
- **Caches tokens** in `~/.config/aws-pipeline-watcher/credentials.yml`
- **Continues monitoring** seamlessly after refresh

## Usage

### Monitor Pipelines

Start monitoring your configured pipelines and CodeBuild projects:

```bash
./bin/aws-pipeline-watcher
```

### Commands

| Command | Description |
|---------|-------------|
| `aws-pipeline-watcher` | Start monitoring (default command) |
| `aws-pipeline-watcher watch` | Start monitoring (explicit) |
| `aws-pipeline-watcher config` | Configure AWS credentials, pipelines, and CodeBuild projects |
| `aws-pipeline-watcher help` | Show help information |

## Display Format

The tool displays pipeline and CodeBuild project information in this format:

```
• item-name
  Status | timer
  commit-hash: commit-message
```

### Status Colors

- 🟢 **Green**: Succeeded
- 🔴 **Red**: Failed
- 🟡 **Yellow**: InProgress
- 🟠 **Light Red**: Stopped
- ⚪ **White**: Other statuses

### Example Output

```
AWS Pipeline/CodeBuild Watcher - Last updated: 2024-01-15 14:30:25
================================================================================

CodePipelines:
• my-web-app-pipeline
  InProgress | 5m 23s (running)
  a1b2c3d4: Add user authentication feature

• api-service-pipeline
  Succeeded | 12m 34s (completed)
  e5f6g7h8: Fix API endpoint validation

• database-migration-pipeline
  Failed | 10m 15s (completed)
  i9j0k1l2: Update database schema for user profiles
    ⚠️  Error: Test suite failed with 3 failures in UserServiceTest
    ⚠️  Summary: Integration tests could not connect to database

CodeBuild Projects:
• my-build-project
  In progress | 3m 45s (running)
  m3n4o5p6

• integration-tests
  Failed | 8m 12s (completed)
  q7r8s9t0
    ⚠️  Error: Test suite failed with 3 failures in UserServiceTest
    ⚠️  BUILD: Command did not complete successfully

Refreshing in 5 seconds... (Press Ctrl+C to exit)
```

### Field Descriptions

- **item-name**: Name of the CodePipeline or CodeBuild project (displayed on first line)
- **Status**: Accurate execution status with intelligent detection (Succeeded/Succeeded, Failed/Failed, InProgress/In progress, etc.)
- **timer**: Duration the pipeline/build has been running or since completion
- **commit-hash**: Short Git commit hash (first 8 characters)
- **commit-message**: Clean commit message extracted from source revision (automatically parses GitHub/CodeCommit JSON format)
- **error-details**: For failed pipelines/builds, up to 2 lines of actionable error information (⚠️ icon)

### Status Accuracy

The tool uses intelligent status detection to provide accurate pipeline and build states:
- **Handles AWS API timing**: When executions show "InProgress" but all actions are complete, status displays as "Succeeded"
- **Consistent display**: Status always matches the step/phase information shown
- **Real-time accuracy**: Shows the true current state of your pipelines and builds
- **Multi-service support**: Unified display for both CodePipeline and CodeBuild with consistent formatting
- **Smart commit parsing**: Automatically extracts clean commit messages from JSON metadata provided by GitHub and CodeCommit

### Error Details for Failed Pipelines

When pipelines or builds fail, the tool automatically displays helpful debugging information:
- **Error messages**: Direct error messages from AWS CodePipeline actions and CodeBuild phases
- **Failure summaries**: Additional context from build/test/deploy tools and build logs
- **Smart truncation**: Long messages are shortened for terminal readability
- **Compact display**: Shows up to 2 lines of error details to maintain clean interface
- **Visual indicators**: Red warning icons (⚠️) highlight error details
- **No configuration needed**: Error details appear automatically for failed pipelines and builds
- **CloudWatch integration**: CodeBuild failures show relevant log group information when available

## AWS Permissions

Your AWS user needs these IAM permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codepipeline:ListPipelines",
                "codepipeline:ListPipelineExecutions",
                "codepipeline:ListActionExecutions",
                "codepipeline:GetPipeline",
                "codebuild:ListProjects",
                "codebuild:ListBuildsForProject",
                "codebuild:BatchGetBuilds"
            ],
            "Resource": "*"
        }
    ]
}
```

## Development

### Running Tests

```bash
bundle exec rspec
```

### Linting

```bash
bundle exec rubocop
```

### Available Rake Tasks

```bash
rake install      # Install dependencies
rake test         # Run tests
rake lint         # Run RuboCop linting
rake check        # Run all checks (tests + linting)
rake install_gem  # Build and install gem locally
rake clean        # Clean up build artifacts
```

## Troubleshooting

### Common Issues

1. **Invalid credentials**: Verify your AWS credentials (CLI or manual)
2. **Permission denied**: Ensure your AWS user has the required CodePipeline and CodeBuild permissions
3. **Pipeline/project not found**: Check pipeline/project name spelling and AWS region
4. **Connection issues**: Verify internet connection and firewall settings
5. **AWS CLI not detected**: Install and configure AWS CLI with `aws configure`
6. **SSO token expired**: Tool will automatically refresh, or manually run `aws sso login`
7. **Config not found**: Configuration is now stored in `~/.config/aws-pipeline-watcher/`

### Getting Help

- Check the [INSTALLATION.md](INSTALLATION.md) for detailed setup instructions
- Run `aws-pipeline-watcher help` for command information
- Verify your AWS credentials and permissions
- Test AWS CLI with `aws sts get-caller-identity` and `aws configure list`
- For SSO issues, verify with `aws sso login --profile your-profile`
- Config location: `~/.config/aws-pipeline-watcher/config.yml`

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
