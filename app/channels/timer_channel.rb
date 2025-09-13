class TimerChannel < ApplicationCable::Channel
  def subscribed
    # Stream for the current user's timer updates
    if current_user
      stream_for current_user
      Rails.logger.info "User #{current_user.name} subscribed to timer channel"

      # Send current timer status on connection
      transmit_current_status
    else
      Rails.logger.warn "Unauthorized timer channel subscription attempt"
      reject
    end
  end

  def unsubscribed
    Rails.logger.info "User #{current_user&.name} unsubscribed from timer channel"
  end

  # Handle start session request from client
  def start_session(data)
    return reject unless current_user

    begin
      session = MultimediaTimerService.start_session(
        current_user,
        session_type: data["session_type"]&.to_sym || :regular
      )

      # Broadcast success
      broadcast_to_user({
        type: :session_started,
        success: true,
        session_id: session.id,
        remaining_minutes: MultimediaTimerService.get_remaining_time(current_user),
        message: "Session started successfully!"
      })

      Rails.logger.info "Timer session started via ActionCable for #{current_user.name}"

    rescue MultimediaTimerService::TimerError => e
      # Broadcast error
      broadcast_to_user({
        type: :session_start_failed,
        success: false,
        error: e.message
      })

      Rails.logger.warn "Timer session start failed for #{current_user.name}: #{e.message}"
    end
  end

  # Handle stop session request from client
  def stop_session(data)
    return reject unless current_user

    begin
      session = MultimediaTimerService.stop_session(current_user)

      # Broadcast success
      broadcast_to_user({
        type: :session_stopped,
        success: true,
        duration_minutes: session.duration_minutes,
        remaining_minutes: MultimediaTimerService.get_remaining_time(current_user),
        message: "Session stopped successfully!"
      })

      Rails.logger.info "Timer session stopped via ActionCable for #{current_user.name}"

    rescue MultimediaTimerService::TimerError => e
      # Broadcast error
      broadcast_to_user({
        type: :session_stop_failed,
        success: false,
        error: e.message
      })

      Rails.logger.warn "Timer session stop failed for #{current_user.name}: #{e.message}"
    end
  end

  # Handle status request from client
  def get_status(data)
    return reject unless current_user

    transmit_current_status
  end

  # Handle ping from client to keep connection alive
  def ping(data)
    return reject unless current_user

    transmit({
      type: :pong,
      timestamp: Time.current.iso8601,
      user_id: current_user.id
    })
  end

  private

  # Send current timer status to the user
  def transmit_current_status
    status = MultimediaTimerService.get_session_status(current_user)

    transmit({
      type: :status_update,
      **status,
      timestamp: Time.current.iso8601
    })
  end

  # Broadcast message to the current user
  def broadcast_to_user(message)
    TimerChannel.broadcast_to(current_user, message.merge(
      timestamp: Time.current.iso8601,
      user_id: current_user.id
    ))
  end

  # Class methods for broadcasting from services/jobs
  class << self
    # Broadcast timer update to a specific user
    def broadcast_timer_update(user, event_type, data = {})
      broadcast_to(user, {
        type: event_type,
        data: data,
        timestamp: Time.current.iso8601,
        user_id: user.id
      })
    end

    # Broadcast session start event
    def broadcast_session_started(user, session)
      broadcast_timer_update(user, :session_started, {
        session_id: session.id,
        session_type: session.session_type,
        remaining_minutes: MultimediaTimerService.get_remaining_time(user),
        message: "Multimedia session started"
      })
    end

    # Broadcast session stop event
    def broadcast_session_stopped(user, session)
      broadcast_timer_update(user, :session_stopped, {
        session_id: session.id,
        duration_minutes: session.duration_minutes,
        remaining_minutes: MultimediaTimerService.get_remaining_time(user),
        message: "Multimedia session ended"
      })
    end

    # Broadcast time warning
    def broadcast_time_warning(user, warning_type, remaining_minutes)
      message = case warning_type
      when :warning_15min
        "15 minutes of multimedia time remaining"
      when :warning_5min
        "5 minutes of multimedia time remaining"
      when :warning_1min
        "1 minute of multimedia time remaining"
      else
        "Time warning"
      end

      broadcast_timer_update(user, warning_type, {
        remaining_minutes: remaining_minutes,
        message: message,
        urgency: warning_type == :warning_1min ? 'high' : 'medium'
      })
    end

    # Broadcast time expired event
    def broadcast_time_expired(user)
      broadcast_timer_update(user, :time_expired, {
        remaining_minutes: 0,
        message: "Your multimedia time has expired for today",
        urgency: 'high'
      })
    end

    # Broadcast bonus time awarded
    def broadcast_bonus_awarded(user, bonus_minutes, reason)
      broadcast_timer_update(user, :bonus_awarded, {
        bonus_minutes: bonus_minutes,
        remaining_minutes: MultimediaTimerService.get_remaining_time(user),
        message: "You earned #{bonus_minutes} minutes of bonus time: #{reason}",
        reason: reason
      })
    end

    # Broadcast emergency session started
    def broadcast_emergency_started(user, parent, reason)
      broadcast_timer_update(user, :emergency_started, {
        started_by: parent.name,
        reason: reason,
        remaining_minutes: MultimediaTimerService.get_remaining_time(user),
        message: "Emergency multimedia session started by #{parent.name}"
      })
    end

    # Broadcast force stop event
    def broadcast_force_stopped(user, stopped_by, reason)
      broadcast_timer_update(user, :force_stopped, {
        stopped_by: stopped_by&.name,
        reason: reason,
        remaining_minutes: MultimediaTimerService.get_remaining_time(user),
        message: "Session stopped by #{stopped_by&.name || 'system'}: #{reason}"
      })
    end

    # Broadcast internet status change
    def broadcast_internet_status(user, enabled, reason = nil)
      broadcast_timer_update(user, :internet_status_changed, {
        internet_enabled: enabled,
        reason: reason,
        message: enabled ? "Internet access restored" : "Internet access blocked"
      })
    end

    # Broadcast system status updates
    def broadcast_system_update(user, update_type, message, data = {})
      broadcast_timer_update(user, :system_update, {
        update_type: update_type,
        message: message,
        **data
      })
    end
  end
end