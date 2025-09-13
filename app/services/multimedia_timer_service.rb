class MultimediaTimerService
  # Custom exceptions for timer operations
  class TimerError < StandardError; end
  class SessionAlreadyActiveError < TimerError; end
  class NoTimeRemainingError < TimerError; end
  class NoActiveSessionError < TimerError; end
  class UnauthorizedError < TimerError; end

  class << self
    # Start a multimedia session for a user
    def start_session(user, session_type: :regular, requested_by: nil)
      validate_start_permission!(user, requested_by)

      # Check if user already has an active session
      existing_session = user.current_multimedia_session
      if existing_session&.running?
        raise SessionAlreadyActiveError, "User already has an active multimedia session"
      end

      # Check if user has time remaining
      remaining_time = get_remaining_time(user)
      if remaining_time <= 0 && session_type != :emergency
        raise NoTimeRemainingError, "No multimedia time remaining for today"
      end

      # Ensure internet is enabled for the user
      internet_state = user.ensure_internet_control_state
      unless internet_state.internet_enabled?
        internet_state.enable_internet!(controlled_by: :timer)
      end

      # Create new session
      session = MultimediaSession.start_for_user(user, session_type: session_type)

      # Broadcast session start event
      broadcast_timer_update(user, :started)

      session
    end

    # Stop the current multimedia session for a user
    def stop_session(user, stopped_by: nil)
      validate_stop_permission!(user, stopped_by)

      session = user.current_multimedia_session
      unless session&.running?
        raise NoActiveSessionError, "No active multimedia session to stop"
      end

      # End the session and calculate final duration
      session.end_session!

      # Update daily usage record
      usage_record = user.todays_usage_record
      usage_record.record_session_usage(session)

      # Check if time is exhausted and disable internet if needed
      remaining_time = get_remaining_time(user)
      if remaining_time <= 0
        disable_internet_for_user(user, reason: "Daily multimedia time exhausted")
      end

      # Broadcast session stop event
      broadcast_timer_update(user, :stopped)

      session
    end

    # Get remaining multimedia time for user today
    def get_remaining_time(user)
      usage_record = user.todays_usage_record
      remaining = usage_record.remaining_minutes

      # If user has an active session, subtract the current session time
      if active_session = user.current_multimedia_session
        current_duration = active_session.current_duration_minutes
        remaining -= current_duration
      end

      [remaining, 0].max
    end

    # Get remaining time in seconds for more precise calculations
    def get_remaining_time_seconds(user)
      get_remaining_time(user) * 60
    end

    # Check if user can start a multimedia session
    def can_start_session?(user)
      return false if user.current_multimedia_session&.running?
      return false if get_remaining_time(user) <= 0
      true
    end

    # Get current session status for user
    def get_session_status(user)
      session = user.current_multimedia_session
      remaining_time = get_remaining_time(user)
      usage_record = user.todays_usage_record

      {
        has_active_session: session&.running? || false,
        session_duration: session&.current_duration_minutes || 0,
        remaining_minutes: remaining_time,
        remaining_seconds: remaining_time * 60,
        daily_usage: usage_record.actual_total_used,
        daily_allowance: usage_record.total_available_minutes,
        usage_percentage: usage_record.usage_percentage,
        can_start_session: can_start_session?(user),
        time_exhausted: remaining_time <= 0,
        session_type: session&.session_type,
        internet_enabled: user.internet_enabled?
      }
    end

    # Add bonus time to user's daily allowance
    def add_bonus_time(user, minutes, reason = "Bonus time earned", todo: nil)
      usage_record = user.todays_usage_record
      max_bonus = user.ensure_multimedia_allowance.max_bonus_minutes

      # Calculate how much bonus time can actually be added
      current_bonus = usage_record.bonus_minutes_earned
      available_bonus_slots = max_bonus - current_bonus
      actual_bonus = [minutes, available_bonus_slots].min

      if actual_bonus > 0
        usage_record.add_bonus_time(actual_bonus)

        # Log the bonus time award
        Rails.logger.info "Bonus time awarded: #{actual_bonus} minutes to #{user.name} - #{reason}"

        # Broadcast update
        broadcast_timer_update(user, :bonus_awarded, { bonus_minutes: actual_bonus, reason: reason })

        actual_bonus
      else
        0
      end
    end

    # Force stop session (admin/parent override)
    def force_stop_session(user, stopped_by:, reason: "Forced stop")
      session = user.current_multimedia_session
      return nil unless session&.running?

      # End session immediately
      session.end_session!

      # Update usage record
      usage_record = user.todays_usage_record
      usage_record.record_session_usage(session)

      # Disable internet
      disable_internet_for_user(user, reason: reason, override_by: stopped_by)

      # Broadcast forced stop
      broadcast_timer_update(user, :force_stopped, { reason: reason, stopped_by: stopped_by&.name })

      session
    end

    # Emergency session start (parent override)
    def start_emergency_session(user, parent:, reason:, duration_minutes: 30)
      unless parent.parent?
        raise UnauthorizedError, "Only parents can start emergency sessions"
      end

      # End any existing session first
      stop_session(user) if user.current_multimedia_session&.running?

      # Enable internet for emergency session
      internet_state = user.ensure_internet_control_state
      internet_state.enable_internet!(
        controlled_by: :manual,
        override_by: parent,
        reason: "Emergency session: #{reason}"
      )

      # Start emergency session
      session = start_session(user, session_type: :emergency, requested_by: parent)

      # Log emergency session
      Rails.logger.warn "Emergency multimedia session started for #{user.name} by #{parent.name}: #{reason}"

      # Broadcast emergency start
      broadcast_timer_update(user, :emergency_started, {
        reason: reason,
        started_by: parent.name,
        duration_minutes: duration_minutes
      })

      session
    end

    # Get timer warnings for user (15min, 5min, 1min remaining)
    def get_timer_warnings(user)
      remaining_seconds = get_remaining_time_seconds(user)
      warnings = []

      # 15 minute warning
      if remaining_seconds <= 15 * 60 && remaining_seconds > 5 * 60
        warnings << { type: :warning_15min, message: "15 minutes of multimedia time remaining" }
      end

      # 5 minute warning
      if remaining_seconds <= 5 * 60 && remaining_seconds > 1 * 60
        warnings << { type: :warning_5min, message: "5 minutes of multimedia time remaining" }
      end

      # 1 minute warning
      if remaining_seconds <= 1 * 60 && remaining_seconds > 0
        warnings << { type: :warning_1min, message: "1 minute of multimedia time remaining" }
      end

      # Time expired
      if remaining_seconds <= 0
        warnings << { type: :time_expired, message: "Multimedia time has expired" }
      end

      warnings
    end

    # Calculate and update usage statistics
    def update_usage_statistics(user)
      usage_record = user.todays_usage_record

      # Recalculate totals from sessions
      daily_sessions = user.multimedia_sessions.for_date(Date.current)

      regular_usage = daily_sessions.regular.sum(:duration_minutes)
      bonus_usage = daily_sessions.bonus.sum(:duration_minutes)

      usage_record.update!(
        total_minutes_used: regular_usage,
        bonus_minutes_used: bonus_usage
      )

      usage_record
    end

    private

    # Validate that the requestor can start a session for the user
    def validate_start_permission!(user, requested_by)
      return true if requested_by.nil? && user.present? # User starting their own session
      return true if requested_by&.parent? # Parent can start anyone's session
      return true if requested_by == user # User starting their own session explicitly

      raise UnauthorizedError, "Not authorized to start multimedia session for this user"
    end

    # Validate that the requestor can stop a session for the user
    def validate_stop_permission!(user, stopped_by)
      return true if stopped_by.nil? && user.present? # User stopping their own session
      return true if stopped_by&.parent? # Parent can stop anyone's session
      return true if stopped_by == user # User stopping their own session explicitly

      raise UnauthorizedError, "Not authorized to stop multimedia session for this user"
    end

    # Disable internet for user when time is exhausted
    def disable_internet_for_user(user, reason: "Time exhausted", override_by: nil)
      internet_state = user.ensure_internet_control_state

      if override_by
        internet_state.disable_internet!(
          controlled_by: :manual,
          override_by: override_by,
          reason: reason
        )
      else
        internet_state.disable_internet!(
          controlled_by: :timer,
          reason: reason
        )
      end

      # Broadcast internet disabled event
      broadcast_timer_update(user, :internet_disabled, { reason: reason })
    end

    # Broadcast timer updates via ActionCable
    def broadcast_timer_update(user, event_type, data = {})
      TimerChannel.broadcast_timer_update(user, event_type, data.merge(get_session_status(user)))
      Rails.logger.info "Timer update for #{user.name}: #{event_type} - #{data}"
    end
  end
end