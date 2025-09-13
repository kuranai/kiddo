class UsageMonitoringJob < ApplicationJob
  queue_as :default

  # Run this job periodically (every minute) to monitor active sessions
  def perform
    Rails.logger.debug "Starting usage monitoring check"

    monitoring_start = Time.current

    begin
      stats = {
        active_sessions_checked: 0,
        warnings_sent: 0,
        sessions_timed_out: 0,
        internet_controls_applied: 0,
        errors: []
      }

      # Get all active multimedia sessions
      active_sessions = MultimediaSession.active.includes(:user)
      stats[:active_sessions_checked] = active_sessions.count

      return if active_sessions.empty?

      Rails.logger.debug "Monitoring #{active_sessions.count} active sessions"

      active_sessions.each do |session|
        begin
          process_session_monitoring(session, stats)
        rescue => e
          error_msg = "Failed to monitor session for #{session.user.name}: #{e.message}"
          Rails.logger.error error_msg
          stats[:errors] << error_msg
        end
      end

      # Log monitoring results
      duration = (Time.current - monitoring_start).round(2)
      if stats.values_at(:warnings_sent, :sessions_timed_out, :internet_controls_applied).sum > 0
        Rails.logger.info "Usage monitoring completed in #{duration}s: #{stats.except(:errors)}"
      else
        Rails.logger.debug "Usage monitoring completed in #{duration}s: no actions needed"
      end

      Rails.logger.warn "Monitoring errors: #{stats[:errors]}" if stats[:errors].any?

    rescue => e
      Rails.logger.error "Usage monitoring job failed: #{e.message}"
      raise
    ensure
      # Schedule the next monitoring run (every minute)
      schedule_next_monitoring
    end
  end

  private

  # Process monitoring for a single session
  def process_session_monitoring(session, stats)
    user = session.user
    remaining_time_minutes = MultimediaTimerService.get_remaining_time(user)
    session_duration = session.current_duration_minutes

    Rails.logger.debug "Monitoring #{user.name}: #{session_duration}min used, #{remaining_time_minutes}min remaining"

    # Check if time has been exhausted
    if remaining_time_minutes <= 0
      handle_time_exhausted(session, stats)
      return
    end

    # Send progressive warnings
    send_time_warnings(user, remaining_time_minutes, stats)

    # Check for unusually long sessions (potential issue)
    check_for_runaway_session(session, stats)
  end

  # Handle when user has exhausted their time
  def handle_time_exhausted(session, stats)
    user = session.user

    begin
      Rails.logger.info "Time exhausted for #{user.name} - ending session and disabling internet"

      # End the session
      MultimediaTimerService.stop_session(user)

      # Disable internet access
      InternetControlService.disable_internet(
        user,
        controlled_by: :timer,
        reason: "Daily multimedia time exhausted"
      )

      stats[:sessions_timed_out] += 1
      stats[:internet_controls_applied] += 1

      # Broadcast timeout event
      broadcast_timeout_event(user)

    rescue MultimediaTimerService::NoActiveSessionError
      # Session was already ended, just disable internet
      InternetControlService.disable_internet(
        user,
        controlled_by: :timer,
        reason: "Daily multimedia time exhausted"
      )
      stats[:internet_controls_applied] += 1
    end
  end

  # Send time warnings at specific thresholds
  def send_time_warnings(user, remaining_minutes, stats)
    # Define warning thresholds (minutes)
    warning_thresholds = {
      15 => :warning_15min,
      5 => :warning_5min,
      1 => :warning_1min
    }

    warning_thresholds.each do |threshold, warning_type|
      if should_send_warning?(user, remaining_minutes, threshold)
        send_warning(user, warning_type, remaining_minutes, stats)
        break # Only send one warning per check to avoid spam
      end
    end
  end

  # Determine if a warning should be sent
  def should_send_warning?(user, remaining_minutes, threshold)
    # Only send warning if:
    # 1. User is at or below the threshold
    # 2. We haven't sent this warning recently (prevent spam)
    return false unless remaining_minutes <= threshold && remaining_minutes > 0

    # Check if we've sent this warning recently using cache/Redis
    cache_key = "warning_sent:#{user.id}:#{threshold}:#{Date.current}"
    return false if Rails.cache.exist?(cache_key)

    true
  end

  # Send a time warning to the user
  def send_warning(user, warning_type, remaining_minutes, stats)
    Rails.logger.info "Sending #{warning_type} warning to #{user.name}: #{remaining_minutes} minutes remaining"

    # Mark warning as sent to prevent spam
    cache_key = "warning_sent:#{user.id}:#{remaining_minutes}:#{Date.current}"
    Rails.cache.write(cache_key, true, expires_in: 1.hour)

    # Broadcast warning via ActionCable
    broadcast_warning(user, warning_type, remaining_minutes)

    stats[:warnings_sent] += 1
  end

  # Check for sessions that have been running unusually long
  def check_for_runaway_session(session, stats)
    max_reasonable_session = 8.hours.to_i / 60 # 8 hours in minutes

    if session.current_duration_minutes > max_reasonable_session
      Rails.logger.warn "Runaway session detected for #{session.user.name}: #{session.current_duration_minutes} minutes"

      # This might indicate a technical issue - log but don't auto-terminate
      # Parent notification could be added here
      broadcast_long_session_alert(session)
    end
  end

  # Broadcast timeout event to user
  def broadcast_timeout_event(user)
    TimerChannel.broadcast_time_expired(user)
    Rails.logger.info "Broadcasting timeout event to #{user.name}"
  end

  # Broadcast warning to user
  def broadcast_warning(user, warning_type, remaining_minutes)
    TimerChannel.broadcast_time_warning(user, warning_type, remaining_minutes)
    Rails.logger.info "Broadcasting #{warning_type} to #{user.name}"
  end

  # Broadcast long session alert
  def broadcast_long_session_alert(session)
    user = session.user
    duration_hours = (session.current_duration_minutes / 60.0).round(1)

    # TODO: Notify parents about unusually long sessions
    # ParentNotificationChannel.broadcast_to_parents({
    #   type: :long_session_alert,
    #   user_name: user.name,
    #   duration_hours: duration_hours,
    #   started_at: session.started_at
    # })

    Rails.logger.warn "Long session alert for #{user.name}: #{duration_hours} hours"
  end

  # Schedule the next monitoring run
  def schedule_next_monitoring
    # Run every minute during active hours (6 AM to 11 PM)
    current_hour = Time.current.hour

    if current_hour >= 6 && current_hour < 23
      # Peak monitoring during active hours - every minute
      next_run = 1.minute.from_now
    else
      # Reduced monitoring during quiet hours - every 5 minutes
      next_run = 5.minutes.from_now
    end

    UsageMonitoringJob.set(wait_until: next_run).perform_later
  end
end