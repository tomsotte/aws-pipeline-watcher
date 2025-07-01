# AWS Pipeline Watcher

A Ruby CLI tool that provides live updates showing the status of AWS CodePipelines with real-time monitoring and colorful output.

## Features

- 🔄 **Real-time monitoring** - Updates every 5 seconds with steady, flicker-free UI
- 🎯 **Accurate status display** - Intelligent status detection that shows true pipeline state
- 🚨 **Error details for failures** - Failed pipelines show 2-3 lines of actionable error information
- 🔐 **AWS SSO support** - Automatic token refresh for AWS SSO users
- 🎨 **Color-coded status** - Easy to identify pipeline states at a glance
- ⚙️ **Easy configuration** - Simple setup with standard config paths (XDG compliant)
- 📊 **Detailed information** - Shows execution status, source revision, timing, and current steps
- 🔧 **Multiple pipeline support** - Monitor several pipelines simultaneously
- 🖥️ **Smooth UI** - In-place updates without screen flickering or blinking

## Prerequisites

- Ruby 3.0.0 or higher
- AWS account with CodePipeline access
- AWS CLI configured (recommended) OR AWS credentials (Access Key ID and Secret Access Key)

## Installation

### Quick Start

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
   chmod +x bin/pipeline-watcher
   ```

### System-wide Installation

To install as a system command:
```bash
sudo ln -s $(pwd)/bin/pipeline-watcher /usr/local/bin/pipeline-watcher
```

## Configuration

Run the configuration command to set up your AWS credentials and specify pipelines to monitor:

```bash
./bin/pipeline-watcher config
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

### Configuration File

Settings are stored in the standard configuration directory:
- **macOS/Linux**: `~/.config/pipeline-watcher/config.yml`
- **Windows**: `%APPDATA%\pipeline-watcher\config.yml`

**Using AWS CLI with SSO (Recommended):**
```yaml
use_aws_cli: true
aws_profile: default
aws_region: us-east-1
aws_account_id: "123456789012"
pipeline_names:
  - my-pipeline-1
  - my-pipeline-2
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
```

### AWS SSO Token Management

For AWS SSO users, the tool automatically:
- **Detects expired tokens** during monitoring
- **Refreshes credentials** using `aws sso login`
- **Caches tokens** in `~/.config/pipeline-watcher/credentials.yml`
- **Continues monitoring** seamlessly after refresh

## Usage

### Monitor Pipelines

Start monitoring your configured pipelines:

```bash
./bin/pipeline-watcher
```

### Commands

| Command | Description |
|---------|-------------|
| `pipeline-watcher` | Start monitoring (default command) |
| `pipeline-watcher watch` | Start monitoring (explicit) |
| `pipeline-watcher config` | Configure AWS credentials and pipelines |
| `pipeline-watcher help` | Show help information |

## Display Format

The tool displays pipeline information in this format:

```
• pipeline-name           | Status               | revision   | started
  current-step                             | timer
```

### Status Colors

- 🟢 **Green**: Succeeded
- 🔴 **Red**: Failed  
- 🟡 **Yellow**: InProgress
- 🟠 **Light Red**: Stopped
- ⚪ **White**: Other statuses

### Example Output

```
AWS Pipeline Watcher - Last updated: 2024-01-15 14:30:25
================================================================================

• my-web-app-pipeline     | InProgress           | a1b2c3d4   | 01/15 14:25
  Deploy:DeployToStaging                   | 5m 23s (running)

• api-service-pipeline    | Succeeded            | e5f6g7h8   | 01/15 13:45
  Completed                                | 12m 34s (completed)

• database-migration      | Failed               | i9j0k1l2   | 01/15 14:20
  Test:RunIntegrationTests (FAILED)        | 10m 15s (completed)
    ⚠️  Error: Test suite failed with 3 failures in UserServiceTest
    ⚠️  Summary: Integration tests could not connect to database

Refreshing in 5 seconds... (Press Ctrl+C to exit)
```

### Field Descriptions

- **pipeline-name**: Name of the CodePipeline
- **Status**: Accurate execution status with intelligent detection (Succeeded, Failed, InProgress, etc.)
- **revision**: Latest source revision (first 8 characters of commit hash)
- **started**: When the last execution started (MM/DD HH:MM format)
- **current-step**: Current stage and action being executed or that failed
- **timer**: Duration the pipeline has been running or since completion
- **error-details**: For failed pipelines, 2-3 lines of actionable error information (⚠️ icon)

### Status Accuracy

The tool uses intelligent status detection to provide accurate pipeline states:
- **Handles AWS API timing**: When executions show "InProgress" but all actions are complete, status displays as "Succeeded"
- **Consistent display**: Status always matches the step information shown
- **Real-time accuracy**: Shows the true current state of your pipelines

### Error Details for Failed Pipelines

When pipelines fail, the tool automatically displays helpful debugging information:
- **Error messages**: Direct error messages from AWS CodePipeline actions
- **Failure summaries**: Additional context from build/test/deploy tools
- **Smart truncation**: Long messages are shortened for terminal readability
- **Visual indicators**: Red warning icons (⚠️) highlight error details
- **No configuration needed**: Error details appear automatically for failed pipelines

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
                "codepipeline:GetPipeline"
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
2. **Permission denied**: Ensure your AWS user has the required CodePipeline permissions
3. **Pipeline not found**: Check pipeline name spelling and AWS region
4. **Connection issues**: Verify internet connection and firewall settings
5. **AWS CLI not detected**: Install and configure AWS CLI with `aws configure`
6. **SSO token expired**: Tool will automatically refresh, or manually run `aws sso login`
7. **Config not found**: Configuration is now stored in `~/.config/pipeline-watcher/`

### Getting Help

- Check the [INSTALLATION.md](INSTALLATION.md) for detailed setup instructions
- Run `pipeline-watcher help` for command information
- Verify your AWS credentials and permissions
- Test AWS CLI with `aws sts get-caller-identity` and `aws configure list`
- For SSO issues, verify with `aws sso login --profile your-profile`
- Config location: `~/.config/pipeline-watcher/config.yml`

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
