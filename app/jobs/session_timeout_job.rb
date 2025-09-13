class SessionTimeoutJob < ApplicationJob
  queue_as :default

  # Handle session timeout for a specific user
  def perform(user_id, session_id = nil, timeout_reason = "time_limit_reached")
    user = User.find(user_id)
    Rails.logger.info "Processing session timeout for #{user.name}: #{timeout_reason}"

    begin
      # Find the session to timeout
      session = if session_id
        user.multimedia_sessions.find(session_id)
      else
        user.current_multimedia_session
      end

      unless session&.running?
        Rails.logger.info "No active session found for #{user.name} - timeout already handled"
        return
      end

      # End the session with timeout reason
      case timeout_reason
      when "time_limit_reached"
        handle_time_limit_timeout(user, session)
      when "parent_override"
        handle_parent_override_timeout(user, session)
      when "emergency_stop"
        handle_emergency_stop(user, session)
      when "system_maintenance"
        handle_system_maintenance_timeout(user, session)
      else
        handle_generic_timeout(user, session, timeout_reason)
      end

    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "User or session not found for timeout: #{e.message}"
    rescue => e
      Rails.logger.error "Session timeout failed for user #{user_id}: #{e.message}"
      raise
    end
  end

  private

  # Handle timeout due to daily time limit being reached
  def handle_time_limit_timeout(user, session)
    Rails.logger.info "Time limit timeout for #{user.name}"

    # Stop the session
    MultimediaTimerService.stop_session(user)

    # Disable internet access
    InternetControlService.disable_internet(
      user,
      controlled_by: :timer,
      reason: "Daily time limit reached"
    )

    # Send timeout notification
    send_timeout_notification(user, "Your daily multimedia time has been used up for today.")

    # Log the timeout
    log_timeout_event(user, session, "time_limit_reached")
  end

  # Handle timeout due to parent override
  def handle_parent_override_timeout(user, session)
    Rails.logger.info "Parent override timeout for #{user.name}"

    # Stop the session
    MultimediaTimerService.force_stop_session(
      user,
      stopped_by: session.metadata&.dig("stopped_by_parent"),
      reason: "Parent override timeout"
    )

    # Send override notification
    send_timeout_notification(user, "Your multimedia session has been stopped by a parent.")

    # Log the timeout
    log_timeout_event(user, session, "parent_override")
  end

  # Handle emergency stop timeout
  def handle_emergency_stop(user, session)
    Rails.logger.warn "Emergency stop timeout for #{user.name}"

    # Immediately end session and disable internet
    session.end_session!
    InternetControlService.disable_internet(
      user,
      controlled_by: :manual,
      reason: "Emergency stop activated"
    )

    # Send emergency notification
    send_timeout_notification(user, "Multimedia access has been stopped due to an emergency.")

    # Log the emergency stop
    log_timeout_event(user, session, "emergency_stop")
  end

  # Handle timeout due to system maintenance
  def handle_system_maintenance_timeout(user, session)
    Rails.logger.info "System maintenance timeout for #{user.name}"

    # Gracefully end session
    MultimediaTimerService.stop_session(user)

    # Send maintenance notification
    send_timeout_notification(user, "Multimedia session ended for system maintenance. Time will be restored afterward.")

    # Don't disable internet permanently for maintenance
    # This could be restored automatically after maintenance

    # Log the maintenance timeout
    log_timeout_event(user, session, "system_maintenance")
  end

  # Handle generic timeout with custom reason
  def handle_generic_timeout(user, session, reason)
    Rails.logger.info "Generic timeout for #{user.name}: #{reason}"

    # Stop the session
    MultimediaTimerService.stop_session(user)

    # Send generic notification
    send_timeout_notification(user, "Your multimedia session has ended: #{reason}")

    # Log the timeout
    log_timeout_event(user, session, reason)
  end

  # Send timeout notification to user
  def send_timeout_notification(user, message)
    # TODO: Implement ActionCable broadcasting
    # TimerChannel.broadcast_to(user, {
    #   type: :session_timeout,
    #   message: message,
    #   timestamp: Time.current,
    #   can_restart: MultimediaTimerService.can_start_session?(user)
    # })

    Rails.logger.info "Timeout notification sent to #{user.name}: #{message}"
  end

  # Log timeout event for auditing
  def log_timeout_event(user, session, reason)
    duration = session.current_duration_minutes
    remaining_time = MultimediaTimerService.get_remaining_time(user)

    Rails.logger.info "Session timeout logged: #{user.name} - #{reason} - Duration: #{duration}min - Remaining: #{remaining_time}min"

    # Could also create a separate audit log table for timeouts
    # TimeoutLog.create!(
    #   user: user,
    #   session: session,
    #   reason: reason,
    #   duration_minutes: duration,
    #   remaining_minutes: remaining_time,
    #   timestamp: Time.current
    # )
  end

  # Schedule a delayed timeout for a session
  def self.schedule_timeout(user, delay_minutes, reason = "time_limit_reached")
    SessionTimeoutJob.set(wait: delay_minutes.minutes).perform_later(
      user.id,
      user.current_multimedia_session&.id,
      reason
    )
  end

  # Cancel a scheduled timeout
  def self.cancel_timeout(user)
    # TODO: Implement job cancellation if needed
    # This would require storing job IDs and canceling them
    Rails.logger.info "Timeout cancellation requested for #{user.name}"
  end
end