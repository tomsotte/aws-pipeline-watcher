# AWS Pipeline Watcher

A Ruby CLI tool that provides live updates showing the status of AWS CodePipelines with real-time monitoring and colorful output.

## Features

- 🔄 **Real-time monitoring** - Updates every 5 seconds
- 🎨 **Color-coded status** - Easy to identify pipeline states at a glance
- ⚙️ **Easy configuration** - Simple setup for AWS credentials and pipeline selection
- 📊 **Detailed information** - Shows execution status, source revision, timing, and current steps
- 🔧 **Multiple pipeline support** - Monitor several pipelines simultaneously

## Prerequisites

- Ruby 2.7.0 or higher
- AWS account with CodePipeline access
- AWS credentials (Access Key ID and Secret Access Key)

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

You'll be prompted for:
- **AWS Access Key ID**: Your AWS access key
- **AWS Secret Access Key**: Your AWS secret key  
- **AWS Region**: The AWS region where your pipelines are located (default: us-east-1)
- **AWS Account ID**: Your AWS account ID (12-digit number)
- **Pipeline names**: Comma-separated list of pipeline names to monitor

### Configuration File

Settings are stored in `~/.pipeline_watcher_config.yml`:

```yaml
aws_access_key_id: YOUR_ACCESS_KEY
aws_secret_access_key: YOUR_SECRET_KEY
aws_region: us-east-1
aws_account_id: "123456789012"
pipeline_names:
  - my-pipeline-1
  - my-pipeline-2
  - production-pipeline
```

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

Refreshing in 5 seconds... (Press Ctrl+C to exit)
```

### Field Descriptions

- **pipeline-name**: Name of the CodePipeline
- **Status**: Current execution status (Succeeded, Failed, InProgress, etc.)
- **revision**: Latest source revision (first 8 characters of commit hash)
- **started**: When the last execution started (MM/DD HH:MM format)
- **current-step**: Current stage and action being executed or that failed
- **timer**: Duration the pipeline has been running or since completion

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

1. **Invalid credentials**: Verify your AWS Access Key ID and Secret Access Key
2. **Permission denied**: Ensure your AWS user has the required CodePipeline permissions
3. **Pipeline not found**: Check pipeline name spelling and AWS region
4. **Connection issues**: Verify internet connection and firewall settings

### Getting Help

- Check the [INSTALLATION.md](INSTALLATION.md) for detailed setup instructions
- Run `pipeline-watcher help` for command information
- Verify your AWS credentials and permissions

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
