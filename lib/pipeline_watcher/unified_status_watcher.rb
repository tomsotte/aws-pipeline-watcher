# frozen_string_literal: true

require 'aws-sdk-codepipeline'
require 'aws-sdk-codebuild'
require 'aws-sdk-sts'
require 'colorize'
require 'time'
require 'json'
require 'open3'
require_relative 'aws_credential_manager'

module PipelineWatcher
  class UnifiedStatusWatcher
    def initialize(config, credential_manager = nil)
      @config = config
      @credential_manager = credential_manager || AwsCredentialManager.new(config)

      @pipeline_client, @codebuild_client, @sts_client = @credential_manager.create_unified_clients
      @item_states = {}
      @total_items = 0
      @pipeline_names = @config['pipeline_names'] || []
      @codebuild_names = @config['codebuild_project_names'] || []
    end

    def start_watching
      @first_run = true
      @item_data = {}
      @total_items = @pipeline_names.size + @codebuild_names.size

      if @total_items == 0
        puts "No pipelines or CodeBuild projects configured to monitor.".colorize(:red)
        puts "Please run 'config' command to add items to monitor.".colorize(:yellow)
        return
      end

      puts "AWS Pipeline/CodeBuild Watcher - Monitoring #{@pipeline_names.size} pipeline(s) and #{@codebuild_names.size} CodeBuild project(s)".colorize(:cyan)
      puts 'Press Ctrl+C to exit'.colorize(:yellow)
      puts '=' * 80

      trap('INT') do
        show_cursor
        puts "\nExiting...".colorize(:yellow)
        exit
      end

      # Hide cursor to prevent flickering
      hide_cursor

      loop do
        begin
          # Check if we need to refresh credentials (every 30 minutes)
          if @credential_manager.should_refresh_credentials?
            check_and_refresh_credentials
            @credential_manager.mark_credentials_checked
          end

          if @first_run
            display_initial_screen
            @first_run = false
          else
            update_display_in_place
          end
          sleep 5
        rescue Aws::Errors::ServiceError => e
          if @credential_manager.credentials_error?(e.message)
            display_error("AWS credentials may be expired, attempting refresh...")
            if @config['use_aws_cli'] && refresh_aws_credentials_runtime
              display_error("Credentials refreshed, retrying...")
              sleep 2
            else
              display_error("AWS Error: #{e.message}")
              sleep 10
            end
          else
            display_error("AWS Error: #{e.message}")
            sleep 10
          end
        rescue StandardError => e
          display_error("Error: #{e.message}")
          sleep 10
        end
      end
    ensure
      show_cursor
    end

    private

    def hide_cursor
      print "\e[?25l"
    end

    def show_cursor
      print "\e[?25h"
    end

    def move_cursor_to(row, col)
      print "\e[#{row};#{col}H"
    end

    def clear_line
      print "\e[K"
    end

    def save_cursor_position
      print "\e[s"
    end

    def restore_cursor_position
      print "\e[u"
    end

    def display_initial_screen
      # Clear screen once and set up the static layout
      system('clear') || system('cls')

      # Display header
      puts "AWS Pipeline/CodeBuild Watcher - Last updated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}".colorize(:cyan)
      puts '=' * 80
      puts

      # Display section headers and reserve space for items
      current_row = 4

      if @pipeline_names.any?
        puts "CodePipelines:".colorize(:light_blue)
        current_row += 1

        @pipeline_names.each_with_index do |pipeline_name, index|
          @item_data[pipeline_name] = { row: current_row + (index * 6), last_display: '', type: :pipeline }
          puts # Pipeline status line
          puts # Pipeline details line
          puts # Pipeline commit line
          puts # Error line 1 (if needed)
          puts # Error line 2 (if needed)
          puts # Empty spacing line
        end
        current_row += @pipeline_names.size * 6 + 1
      end

      if @codebuild_names.any?
        puts "CodeBuild Projects:".colorize(:light_blue)
        current_row += 1

        @codebuild_names.each_with_index do |project_name, index|
          @item_data[project_name] = { row: current_row + (index * 6), last_display: '', type: :codebuild }
          puts # Build status line
          puts # Build details line
          puts # Build commit line
          puts # Error line 1 (if needed)
          puts # Error line 2 (if needed)
          puts # Empty spacing line
        end
      end

      puts
      puts 'Refreshing in 5 seconds... (Press Ctrl+C to exit)'.colorize(:light_black)

      # Now populate with actual data
      @pipeline_names.each do |pipeline_name|
        update_pipeline_display(pipeline_name)
      end

      @codebuild_names.each do |project_name|
        update_codebuild_display(project_name)
      end

      # Update header timestamp
      update_header_timestamp
    end

    def update_display_in_place
      # Update timestamp in header
      update_header_timestamp

      # Update each pipeline's display
      @pipeline_names.each do |pipeline_name|
        update_pipeline_display(pipeline_name)
      end

      # Update each CodeBuild project's display
      @codebuild_names.each do |project_name|
        update_codebuild_display(project_name)
      end
    end

    def update_header_timestamp
      move_cursor_to(1, 1)
      clear_line
      print "AWS Pipeline/CodeBuild Watcher - Last updated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}".colorize(:cyan)
    end

    def display_error(message)
      # Display error at the bottom without disrupting the main display
      save_cursor_position
      move_cursor_to(@total_items * 6 + 8, 1)
      clear_line
      print message.colorize(:red)
      restore_cursor_position
    end

    def update_pipeline_display(pipeline_name)
      begin
        pipeline_execution = get_latest_pipeline_execution(pipeline_name)

        if pipeline_execution
          status = pipeline_execution.status
          started_at = pipeline_execution.start_time
          source_revision = get_pipeline_source_revision(pipeline_execution)

          # Get current step info and actual status
          step_info = get_pipeline_current_step_info(pipeline_name, pipeline_execution.pipeline_execution_id)

          # Use the actual status from step analysis if it's more accurate than execution status
          actual_status = step_info[:actual_status] || status

          # If execution says InProgress but steps show Completed, trust the steps
          if status == 'InProgress' && step_info[:step] == 'Completed'
            actual_status = 'Succeeded'
          end

          # Calculate timer
          timer = calculate_timer(started_at, actual_status)

          new_display = format_pipeline_display(pipeline_name, actual_status, timer, source_revision, step_info[:error_details], step_info[:step])
        else
          new_display = format_no_execution_display(pipeline_name)
        end

        # Only update if the display has changed
        item_info = @item_data[pipeline_name]
        if item_info[:last_display] != new_display
          update_item_lines(pipeline_name, new_display)
          item_info[:last_display] = new_display
        end
      rescue StandardError => e
        error_display = format_error_display(pipeline_name, e.message)
        item_info = @item_data[pipeline_name]
        if item_info[:last_display] != error_display
          update_item_lines(pipeline_name, error_display)
          item_info[:last_display] = error_display
        end
      end
    end

    def update_codebuild_display(project_name)
      begin
        builds = get_recent_builds(project_name)

        if builds && !builds.empty?
          latest_build = builds.first
          status = latest_build.build_status
          started_at = latest_build.start_time
          source_revision = get_build_source_revision(latest_build)

          # Get current phase info
          phase_info = get_current_phase_info(latest_build)

          # Calculate timer
          timer = calculate_build_timer(started_at, status, latest_build.end_time)

          new_display = format_build_display(project_name, status, timer, source_revision, phase_info[:error_details], phase_info[:phase])
        else
          new_display = format_no_builds_display(project_name)
        end

        # Only update if the display has changed
        item_info = @item_data[project_name]
        if item_info[:last_display] != new_display
          update_item_lines(project_name, new_display)
          item_info[:last_display] = new_display
        end
      rescue StandardError => e
        error_display = format_error_display(project_name, e.message)
        item_info = @item_data[project_name]
        if item_info[:last_display] != error_display
          update_item_lines(project_name, error_display)
          item_info[:last_display] = error_display
        end
      end
    end

    def format_pipeline_display(name, status, timer, source_revision, error_details = nil, step = nil)
      # Determine step display and color based on status and step info
      if step
        if step == 'Completed'
          step_display = 'Completed'
          step_color = :green
        elsif step.include?('FAILED')
          step_display = step
          step_color = :red
        elsif status == 'InProgress'
          step_display = step
          step_color = :yellow
        elsif status == 'Succeeded'
          step_display = 'Completed'
          step_color = :green
        elsif status == 'Failed'
          step_display = step.include?('FAILED') ? step : "#{step} (FAILED)"
          step_color = :red
        else
          step_display = step
          step_color = :cyan
        end
      else
        # Fallback to status-based display
        step_display = status
        step_color = case status
                     when 'Succeeded' then :green
                     when 'Failed' then :red
                     when 'InProgress' then :yellow
                     when 'Stopped' then :light_red
                     else :white
                     end
      end

      line1 = "• #{name}"
      line2 = "  #{step_display.colorize(step_color)} | #{timer.colorize(:light_black)}"
      line3 = "  #{source_revision}".colorize(:light_black)

      # Add error details for failed pipelines
      lines = { line1: line1, line2: line2, line3: line3 }

      if status == 'Failed' && error_details && !error_details.empty?
        lines[:error_lines] = error_details[0..1].map { |detail| "    ⚠️  #{detail}".colorize(:red) }
      end

      lines
    end

    def format_build_display(name, status, timer, source_revision, error_details = nil, phase = nil)
      # Determine phase display and color based on status and phase info
      if phase
        if phase == 'Completed'
          phase_display = 'Completed'
          phase_color = :green
        elsif phase.include?('FAILED') || phase == 'Failed'
          phase_display = phase
          phase_color = :red
        elsif phase.include?('running') || status == 'IN_PROGRESS'
          phase_display = phase
          phase_color = :yellow
        elsif status == 'SUCCEEDED'
          phase_display = 'Completed'
          phase_color = :green
        elsif status == 'FAILED' || status == 'FAULT' || status == 'TIMED_OUT'
          phase_display = phase.include?('FAILED') ? phase : "#{phase} (FAILED)"
          phase_color = :red
        else
          phase_display = phase
          phase_color = :cyan
        end
      else
        # Fallback to status-based display
        phase_display = status.gsub('_', ' ').downcase.capitalize
        phase_color = case status
                      when 'SUCCEEDED' then :green
                      when 'FAILED' then :red
                      when 'IN_PROGRESS' then :yellow
                      when 'STOPPED' then :light_red
                      when 'FAULT' then :red
                      when 'TIMED_OUT' then :light_red
                      else :white
                      end
      end

      line1 = "• #{name}"
      line2 = "  #{phase_display.colorize(phase_color)} | #{timer.colorize(:light_black)}"
      line3 = "  #{source_revision}".colorize(:light_black)

      # Add error details for failed builds
      lines = { line1: line1, line2: line2, line3: line3 }

      if (status == 'FAILED' || status == 'FAULT' || status == 'TIMED_OUT') && error_details && !error_details.empty?
        lines[:error_lines] = error_details[0..1].map { |detail| "    ⚠️  #{detail}".colorize(:red) }
      end

      lines
    end

    def format_no_execution_display(item_name)
      line1 = "• #{item_name}"
      line2 = "  No executions found".colorize(:light_black)
      line3 = "  ".colorize(:light_black)

      { line1: line1, line2: line2, line3: line3 }
    end

    def format_no_builds_display(item_name)
      line1 = "• #{item_name}"
      line2 = "  No builds found".colorize(:light_black)
      line3 = "  ".colorize(:light_black)

      { line1: line1, line2: line2, line3: line3 }
    end

    def format_error_display(item_name, error_message)
      line1 = "• #{item_name}"
      line2 = "  Error: #{error_message}".colorize(:red)
      line3 = "  ".colorize(:light_black)

      { line1: line1, line2: line2, line3: line3 }
    end

    def update_item_lines(item_name, display_data)
      item_info = @item_data[item_name]
      row = item_info[:row]

      # Update first line (status)
      move_cursor_to(row, 1)
      clear_line
      print display_data[:line1]

      # Update second line (details)
      move_cursor_to(row + 1, 1)
      clear_line
      print display_data[:line2]

      # Update third line (commit info)
      move_cursor_to(row + 2, 1)
      clear_line
      print display_data[:line3]

      # Update error details if present
      if display_data[:error_lines]
        display_data[:error_lines].each_with_index do |error_line, index|
          move_cursor_to(row + 3 + index, 1)
          clear_line
          print error_line
        end

        # Clear any remaining error lines from previous display
        (display_data[:error_lines].size..1).each do |index|
          move_cursor_to(row + 3 + index, 1)
          clear_line
        end
      else
        # Clear any previous error lines
        (0..1).each do |index|
          move_cursor_to(row + 3 + index, 1)
          clear_line
        end
      end
    end

    # Pipeline-specific methods
    def get_latest_pipeline_execution(pipeline_name)
      response = @pipeline_client.list_pipeline_executions({
                                                              pipeline_name: pipeline_name,
                                                              max_results: 1
                                                            })

      response.pipeline_execution_summaries.first
    end

    def get_pipeline_source_revision(execution)
      if execution.source_revisions && !execution.source_revisions.empty?
        source_revision = execution.source_revisions.first
        revision_id = source_revision.revision_id

        # Try to get commit message if available
        if source_revision.revision_summary && !source_revision.revision_summary.empty?
          commit_message = source_revision.revision_summary

          # Try to parse JSON if it looks like JSON
          if commit_message.start_with?('{') && commit_message.include?('CommitMessage')
            begin
              parsed = JSON.parse(commit_message)
              commit_message = parsed['CommitMessage'] if parsed['CommitMessage']
            rescue JSON::ParserError
              # If parsing fails, use the original string
            end
          end

          # Truncate long commit messages for display
          if commit_message.length > 80
            commit_message = commit_message[0..77] + '...'
          end
          short_hash = revision_id.length > 8 ? revision_id[0..7] : revision_id
          "#{short_hash}: #{commit_message}"
        else
          # Just show the short hash if no commit message
          short_hash = revision_id.length > 8 ? revision_id[0..7] : revision_id
          "#{short_hash}"
        end
      else
        'N/A'
      end
    end

    def get_pipeline_current_step_info(pipeline_name, execution_id)
      response = @pipeline_client.list_action_executions({
                                                            pipeline_name: pipeline_name,
                                                            filter: {
                                                              pipeline_execution_id: execution_id
                                                            }
                                                          })

      # Find the currently running or most recent failed action
      running_action = response.action_execution_details.find { |action| action.status == 'InProgress' }
      failed_action = response.action_execution_details.find { |action| action.status == 'Failed' }

      if running_action
        { step: "#{running_action.stage_name}:#{running_action.action_name}", actual_status: 'InProgress', error_details: nil }
      elsif failed_action
        error_details = get_pipeline_failure_details(failed_action)
        { step: "#{failed_action.stage_name}:#{failed_action.action_name} (FAILED)", actual_status: 'Failed', error_details: error_details }
      else
        { step: 'Completed', actual_status: 'Succeeded', error_details: nil }
      end
    rescue StandardError
      { step: 'Unknown', actual_status: nil, error_details: nil }
    end

    def get_pipeline_failure_details(failed_action)
      details = []

      # Get error message from action execution
      if failed_action.error_details && failed_action.error_details.message
        error_msg = failed_action.error_details.message
        # Truncate long error messages
        error_msg = error_msg[0..120] + '...' if error_msg.length > 120
        details << "Error: #{error_msg}"
      end

      # Get failure summary if available
      if failed_action.output && failed_action.output.execution_result
        result = failed_action.output.execution_result
        if result.external_execution_summary
          summary = result.external_execution_summary
          summary = summary[0..80] + '...' if summary.length > 80
          details << "Summary: #{summary}"
        end
      end

      # If no specific error details, provide generic info
      if details.empty?
        details << "Action failed in #{failed_action.stage_name} stage"
        details << "Check AWS Console for detailed error information"
      end

      # Limit to 2 lines
      details[0..1]
    rescue StandardError
      ["Failed action details unavailable"]
    end

    # CodeBuild-specific methods
    def get_recent_builds(project_name)
      response = @codebuild_client.list_builds_for_project({
                                                             project_name: project_name,
                                                             sort_order: 'DESCENDING'
                                                           })

      # Get the most recent build ID
      return [] if response.ids.empty?

      # Get detailed information for the most recent build
      builds_response = @codebuild_client.batch_get_builds({
                                                             ids: [response.ids.first]
                                                           })

      builds_response.builds
    end

    def get_build_source_revision(build)
      if build.source_version
        revision = build.source_version
        # Handle different source version formats
        if revision.start_with?('arn:aws:s3:')
          # S3 source
          'S3 source'
        elsif revision.length > 8
          # Git commit hash
          "#{revision[0..7]}"
        else
          revision
        end
      else
        'N/A'
      end
    end

    def get_current_phase_info(build)
      if build.current_phase
        phase_name = build.current_phase
        phase_status = build.build_status

        case phase_status
        when 'IN_PROGRESS'
          { phase: "#{phase_name} (running)", error_details: nil }
        when 'FAILED', 'FAULT', 'TIMED_OUT'
          error_details = get_build_failure_details(build)
          { phase: "#{phase_name} (FAILED)", error_details: error_details }
        else
          { phase: 'Completed', error_details: nil }
        end
      else
        case build.build_status
        when 'SUCCEEDED'
          { phase: 'Completed', error_details: nil }
        when 'FAILED', 'FAULT', 'TIMED_OUT'
          error_details = get_build_failure_details(build)
          { phase: 'Failed', error_details: error_details }
        else
          { phase: 'Unknown', error_details: nil }
        end
      end
    rescue StandardError
      { phase: 'Unknown', error_details: nil }
    end

    def get_build_failure_details(build)
      details = []

      # Get logs and error information
      if build.logs && build.logs.cloud_watch_logs && build.logs.cloud_watch_logs.status == 'ENABLED'
        # Try to get error from CloudWatch logs group/stream info
        if build.logs.cloud_watch_logs.group_name
          details << "Logs: #{build.logs.cloud_watch_logs.group_name}"
        end
      end

      # Get phase failure details
      if build.phases
        failed_phases = build.phases.select { |phase| phase.phase_status == 'FAILED' }
        failed_phases.each do |phase|
          if phase.contexts && !phase.contexts.empty?
            phase.contexts.each do |context|
              if context.message
                msg = context.message
                msg = msg[0..100] + '...' if msg.length > 100
                details << "#{phase.phase_type}: #{msg}"
              end
            end
          else
            details << "#{phase.phase_type} phase failed"
          end
        end
      end

      # If no specific error details, provide generic info
      if details.empty?
        case build.build_status
        when 'FAILED'
          details << "Build failed - check CloudWatch logs for details"
        when 'FAULT'
          details << "Build encountered a fault"
        when 'TIMED_OUT'
          details << "Build timed out"
        end
      end

      # Limit to 2 lines
      details[0..1]
    rescue StandardError
      ["Build failure details unavailable"]
    end

    def check_and_refresh_credentials
      unless @credential_manager.credentials_valid?(@sts_client)
        puts 'Credentials expired, refreshing...'.colorize(:yellow)
        refresh_aws_credentials_runtime
      end
    end

    def refresh_aws_credentials_runtime
      @pipeline_client, @codebuild_client, @sts_client = @credential_manager.refresh_runtime_unified_clients(@pipeline_client, @codebuild_client, @sts_client)
      @credential_manager.credentials_valid?(@sts_client)
    end

    def calculate_timer(started_at, status)
      return 'N/A' unless started_at

      duration = Time.now - started_at

      case status
      when 'InProgress'
        "#{format_duration(duration)} (running)"
      when 'Succeeded', 'Failed', 'Stopped'
        "#{format_duration(duration)} (completed)"
      else
        format_duration(duration)
      end
    end

    def calculate_build_timer(started_at, status, ended_at = nil)
      return 'N/A' unless started_at

      if status == 'IN_PROGRESS'
        duration = Time.now - started_at
        "#{format_duration(duration)} (running)"
      elsif ended_at
        duration = ended_at - started_at
        "#{format_duration(duration)} (completed)"
      else
        duration = Time.now - started_at
        "#{format_duration(duration)} (completed)"
      end
    end

    def format_duration(seconds)
      hours = (seconds / 3600).to_i
      minutes = ((seconds % 3600) / 60).to_i
      secs = (seconds % 60).to_i

      if hours.positive?
        "#{hours}h #{minutes}m #{secs}s"
      elsif minutes.positive?
        "#{minutes}m #{secs}s"
      else
        "#{secs}s"
      end
    end
  end
end
