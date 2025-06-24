# Installation and Usage Guide

## Prerequisites

- Ruby 2.7.0 or higher
- AWS account with CodePipeline access
- AWS credentials (Access Key ID and Secret Access Key)

## Installation

### Option 1: Local Installation

1. Clone or download this repository
2. Navigate to the project directory:
   ```bash
   cd aws-pipeline-watcher
   ```

3. Install dependencies:
   ```bash
   bundle install
   ```

4. Make the executable file runnable:
   ```bash
   chmod +x bin/pipeline-watcher
   ```

### Option 2: System-wide Installation

If you want to install this as a system command:

1. Follow steps 1-3 from Option 1
2. Create a symlink in your PATH:
   ```bash
   sudo ln -s $(pwd)/bin/pipeline-watcher /usr/local/bin/pipeline-watcher
   ```

## Configuration

Before using the pipeline watcher, you need to configure your AWS credentials and specify which pipelines to monitor.

Run the configuration command:
```bash
./bin/pipeline-watcher config
```

Or if installed system-wide:
```bash
pipeline-watcher config
```

You will be prompted for:
- **AWS Access Key ID**: Your AWS access key
- **AWS Secret Access Key**: Your AWS secret key
- **AWS Region**: The AWS region where your pipelines are located (default: us-east-1)
- **AWS Account ID**: Your AWS account ID
- **Pipeline names**: Comma-separated list of pipeline names to monitor

### Configuration File

The configuration is stored in `~/.pipeline_watcher_config.yml`. You can manually edit this file if needed:

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

### Watch Pipeline Status

To start monitoring your configured pipelines:

```bash
./bin/pipeline-watcher
```

Or:
```bash
./bin/pipeline-watcher watch
```

### Display Format

The tool displays information in the following format:

```
• pipeline-name           | Status               | revision   | started
  current-step                             | timer
```

Where:
- **pipeline-name**: Name of the CodePipeline
- **Status**: Current execution status (Succeeded, Failed, InProgress, etc.)
- **revision**: Latest source revision (first 8 characters of commit hash)
- **started**: When the last execution started (MM/DD HH:MM format)
- **current-step**: Current stage and action being executed or that failed
- **timer**: How long the pipeline has been running or since completion

### Status Colors

- **Green**: Succeeded
- **Red**: Failed
- **Yellow**: InProgress
- **Light Red**: Stopped
- **White**: Other statuses

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

## Commands

### Configuration
```bash
pipeline-watcher config
```
Configure AWS credentials and pipeline settings.

### Watch (Default)
```bash
pipeline-watcher
pipeline-watcher watch
```
Start monitoring pipeline statuses with live updates every 5 seconds.

### Help
```bash
pipeline-watcher help
```
Show available commands and options.

## Troubleshooting

### AWS Authentication Issues

1. **Invalid credentials**: Verify your AWS Access Key ID and Secret Access Key
2. **Permission denied**: Ensure your AWS user has the following permissions:
   - `codepipeline:ListPipelines`
   - `codepipeline:ListPipelineExecutions`
   - `codepipeline:ListActionExecutions`
   - `codepipeline:GetPipeline`

### Pipeline Not Found

- Verify the pipeline name is spelled correctly
- Ensure the pipeline exists in the specified AWS region
- Check that your AWS account ID is correct

### Connection Issues

- Verify your internet connection
- Check if you're behind a firewall that might block AWS API calls
- Ensure the AWS region is correct

### Performance Issues

- If monitoring many pipelines, consider reducing the number to improve performance
- The refresh interval is fixed at 5 seconds to balance real-time updates with API rate limits

## AWS IAM Policy

Create an IAM policy with the following permissions for your AWS user:

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

## Exit

Press `Ctrl+C` to stop monitoring and exit the application.