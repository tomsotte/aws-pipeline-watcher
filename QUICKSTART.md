# Quick Start Guide

## AWS Pipeline Watcher

Get up and running with AWS Pipeline Watcher in just a few minutes!

## 🚀 Installation

### Prerequisites
- Ruby 2.6.0 or higher
- AWS account with CodePipeline access
- AWS CLI configured (recommended) OR AWS credentials (Access Key ID and Secret Access Key)

### Setup Steps

1. **Clone and Install**
   ```bash
   git clone <repository-url>
   cd aws-pipeline-watcher
   bundle install --path vendor/bundle
   chmod +x bin/pipeline-watcher
   ```

2. **Configure AWS Credentials**
   ```bash
   bundle exec ./bin/pipeline-watcher config
   ```
   
   **Option A: Use AWS CLI (Recommended)**
   - The tool will auto-detect your AWS CLI configuration
   - Just confirm to use AWS CLI credentials when prompted
   - Region and Account ID will be detected automatically
   
   **Option B: Manual Credentials**
   - Enter AWS Access Key ID and Secret Access Key manually
   - Specify AWS Region and Account ID
   
   Then enter:
   - Pipeline names (comma-separated)

3. **Start Monitoring**
   ```bash
   bundle exec ./bin/pipeline-watcher
   ```

## 📊 What You'll See

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

## 🎨 Status Colors

- 🟢 **Green**: Succeeded
- 🔴 **Red**: Failed
- 🟡 **Yellow**: InProgress
- 🟠 **Orange**: Stopped

## ⚡ Quick Commands

| Command | Action |
|---------|--------|
| `bundle exec ./bin/pipeline-watcher` | Start monitoring |
| `bundle exec ./bin/pipeline-watcher config` | Configure settings |
| `bundle exec ./bin/pipeline-watcher help` | Show help |

## 🔧 Configuration File

Settings are stored in `~/.pipeline_watcher_config.yml`:

**Using AWS CLI (Recommended):**
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

## 🛡️ Required AWS Permissions

Create an IAM policy with these permissions:
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

## 🎯 Key Features

- ✅ **Real-time updates** every 5 seconds
- ✅ **Multiple pipeline monitoring**
- ✅ **Color-coded status indicators**
- ✅ **Execution timing and progress**
- ✅ **Current step identification**
- ✅ **Easy configuration management**

## 🐛 Troubleshooting

### Common Issues

1. **"Configuration missing"** → Run `bundle exec ./bin/pipeline-watcher config`
2. **"Permission denied"** → Check AWS IAM permissions
3. **"Pipeline not found"** → Verify pipeline names and AWS region
4. **Ruby version error** → Ensure Ruby 2.6.0 or higher
5. **AWS CLI not detected** → Install and configure AWS CLI with `aws configure`

### Quick Fixes

```bash
# Reinstall dependencies
bundle install --path vendor/bundle

# Reconfigure
bundle exec ./bin/pipeline-watcher config

# Check configuration
cat ~/.pipeline_watcher_config.yml

# Verify AWS CLI setup
aws sts get-caller-identity
aws configure list
```

## 🧪 Demo Mode

Try the demo to see how it works:
```bash
bundle exec ruby demo.rb
```

## 🧪 Development

```bash
# Run tests
bundle exec rspec

# Run linting
bundle exec rubocop

# Run all checks
bundle exec rake check
```

## 💡 Tips

- **Use AWS CLI**: More secure and convenient than hardcoded access keys
- **AWS profiles**: Use different AWS CLI profiles for different accounts/regions
- **Monitor multiple regions**: Configure separate instances for different AWS regions
- **Use IAM roles**: For better security, consider using IAM roles instead of access keys
- **Pipeline naming**: Use descriptive pipeline names for easier identification
- **Terminal size**: Ensure your terminal is wide enough for the full display

## 🆘 Need Help?

- Check the [README.md](README.md) for detailed documentation
- See [INSTALLATION.md](INSTALLATION.md) for comprehensive setup instructions
- Run `bundle exec ./bin/pipeline-watcher help` for command help

---

🎉 **You're all set!** Your AWS CodePipelines are now being monitored in real-time.

Press `Ctrl+C` to stop monitoring when you're done.