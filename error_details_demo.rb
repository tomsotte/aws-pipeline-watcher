#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to showcase the error details feature for failed pipelines
# This demonstrates how the tool now shows helpful error information when pipelines fail

require_relative 'lib/pipeline_watcher'
require 'yaml'

puts 'AWS Pipeline Watcher - Error Details Feature Demo'.colorize(:cyan)
puts '=' * 60
puts 'This demo shows how failed pipelines now display helpful error information!'
puts
puts 'New Feature:'.colorize(:green)
puts '• Failed pipelines show 2-3 lines of error details'
puts '• Error messages from AWS CodePipeline actions'
puts '• Failure summaries and diagnostic information'
puts '• Truncated for readability but still informative'
puts
puts '=' * 60
puts

# Show the improvement
puts 'BEFORE (Limited Information):'.colorize(:red)
puts '• my-pipeline               | Failed     | abc12345   | 01/15 14:25'
puts '  Test:RunUnitTests (FAILED)             | 10m 15s (completed)'
puts
puts '❌ No error details - users had to check AWS Console manually'
puts

puts 'AFTER (Rich Error Information):'.colorize(:green)
puts '• my-pipeline               | Failed     | abc12345   | 01/15 14:25'
puts '  Test:RunUnitTests (FAILED)             | 10m 15s (completed)'
puts '    ⚠️  Error: Test suite failed with 3 failures in UserServiceTest'.colorize(:red)
puts '    ⚠️  Summary: Integration tests could not connect to database'.colorize(:red)
puts
puts '✅ Clear error information helps with quick debugging!'
puts

puts 'Sample Error Scenarios:'.colorize(:yellow)
puts '=' * 30
puts

# Scenario 1: Build Failure
puts '1. Build Stage Failure:'.colorize(:cyan)
puts '• web-app-build              | Failed     | def67890   | 01/15 13:20'
puts '  Build:CodeBuild (FAILED)               | 8m 45s (completed)'
puts '    ⚠️  Error: Build failed with exit code 1'.colorize(:red)
puts '    ⚠️  Summary: npm install failed - dependency version conflict'.colorize(:red)
puts

# Scenario 2: Test Failure
puts '2. Test Stage Failure:'.colorize(:cyan)
puts '• api-testing                | Failed     | ghi11111   | 01/15 14:10'
puts '  Test:RunIntegrationTests (FAILED)      | 12m 30s (completed)'
puts '    ⚠️  Error: 5 tests failed in authentication module'.colorize(:red)
puts '    ⚠️  Summary: Database connection timeout after 30 seconds'.colorize(:red)
puts

# Scenario 3: Deploy Failure
puts '3. Deploy Stage Failure:'.colorize(:cyan)
puts '• production-deploy          | Failed     | jkl22222   | 01/15 15:00'
puts '  Deploy:ECSDeployment (FAILED)          | 15m 12s (completed)'
puts '    ⚠️  Error: Service deployment failed - health check timeout'.colorize(:red)
puts '    ⚠️  Summary: New task definition could not pass ALB health checks'.colorize(:red)
puts

# Scenario 4: Permission Failure
puts '4. Permission Issue:'.colorize(:cyan)
puts '• security-scan              | Failed     | mno33333   | 01/15 16:15'
puts '  Security:ScanCode (FAILED)             | 2m 18s (completed)'
puts '    ⚠️  Error: Access denied to S3 bucket security-scan-results'.colorize(:red)
puts '    ⚠️  Summary: IAM role lacks s3:PutObject permission'.colorize(:red)
puts

puts 'Technical Implementation:'.colorize(:magenta)
puts '=' * 35
puts
puts 'Error Details Sources:'
puts '• Action error messages from AWS CodePipeline API'
puts '• External execution summaries (CodeBuild, etc.)'
puts '• Stage and action failure context'
puts '• Fallback to generic helpful messages'
puts
puts 'Display Features:'
puts '• Maximum 2-3 lines per failed pipeline'
puts '• Messages truncated for terminal readability'
puts '• Red warning icons (⚠️) for visual emphasis'
puts '• Smart formatting that fits terminal width'
puts
puts 'Error Message Processing:'
puts '• Long messages truncated with "..." indicator'
puts '• HTML/special characters cleaned up'
puts '• Multiple error sources combined intelligently'
puts '• Graceful handling when error details unavailable'
puts

puts 'Benefits for DevOps Teams:'.colorize(:green)
puts '=' * 30
puts '✅ Faster debugging - see error details immediately'
puts '✅ Less context switching - no need to open AWS Console'
puts '✅ Better team awareness - error details visible to everyone'
puts '✅ Historical context - understand failure patterns'
puts '✅ Improved MTTR - quicker mean time to resolution'
puts

puts 'Error Detail Examples:'.colorize(:blue)
puts '=' * 25
puts 'Common Error Types:'
puts
puts '• Build Failures:'
puts '  "Error: npm ERR! peer dep missing: react@^17.0.0"'
puts '  "Summary: Dependency resolution failed in package.json"'
puts
puts '• Test Failures:'
puts '  "Error: 12 tests failed, 3 tests timed out"'
puts '  "Summary: Database migration test suite failures"'
puts
puts '• Deployment Failures:'
puts '  "Error: ECS service failed to reach steady state"'
puts '  "Summary: Health check failing on port 8080"'
puts
puts '• Permission Issues:'
puts '  "Error: Access denied: User not authorized to perform sts:AssumeRole"'
puts '  "Summary: Cross-account role assumption failed"'
puts

puts 'Configuration:'.colorize(:yellow)
puts '=' * 15
puts 'Error details display is automatic!'
puts '• No additional configuration required'
puts '• Works with existing AWS credentials'
puts '• Respects AWS API rate limits'
puts '• Handles API errors gracefully'
puts

puts 'Usage Examples:'.colorize(:cyan)
puts '=' * 18
puts
puts '# Monitor your pipelines with rich error details'
puts 'bundle exec ./bin/pipeline-watcher'
puts
puts '# Configure once, then enjoy detailed error information'
puts 'bundle exec ./bin/pipeline-watcher config'
puts
puts '# Error details appear automatically for failed pipelines'
puts '# Look for red warning icons (⚠️) below failed pipeline status'
puts

puts 'Testing:'.colorize(:blue)
puts '=' * 10
puts '• 32 test cases now pass (up from 27)'
puts '• Comprehensive error detail extraction tests'
puts '• Message truncation and formatting validation'
puts '• Error handling for missing or malformed error data'
puts '• UI layout tests for error line display'
puts

puts 'Space Management:'.colorize(:magenta)
puts '=' * 20
puts 'The tool now reserves more space per pipeline:'
puts '• Line 1: Pipeline status (name, status, revision, time)'
puts '• Line 2: Current step and timer information'
puts '• Line 3-5: Error details (only for failed pipelines)'
puts '• Line 6: Spacing line'
puts
puts 'This ensures failed pipelines have room for error details'
puts 'while successful pipelines use minimal space.'
puts

puts '=' * 60
puts 'Error Details Feature Demo Complete!'.colorize(:green)
puts
puts 'Key Takeaways:'.colorize(:yellow)
puts '• Failed pipelines now show actionable error information'
puts '• 2-3 lines of relevant debugging details'
puts '• No additional configuration required'
puts '• Improves debugging efficiency significantly'
puts '• Works with all AWS CodePipeline error sources'
puts
puts 'Start using it now:'.colorize(:cyan)
puts '  bundle exec ./bin/pipeline-watcher'
puts
puts 'Happy debugging! 🐛🔧✅'
