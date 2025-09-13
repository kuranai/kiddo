class MidnightResetJob < ApplicationJob
  queue_as :default

  # Run this job every day at midnight to reset daily multimedia allowances
  def perform(date = Date.current)
    Rails.logger.info "Starting midnight reset job for #{date}"

    reset_start_time = Time.current

    begin
      # Statistics for reporting
      stats = {
        users_processed: 0,
        allowances_reset: 0,
        sessions_ended: 0,
        internet_controls_reset: 0,
        errors: []
      }

      # End any active sessions that are still running
      active_sessions = MultimediaSession.active.includes(:user)
      Rails.logger.info "Found #{active_sessions.count} active sessions to end"

      active_sessions.find_each do |session|
        begin
          # End the session with midnight reset reason
          session.ended_at = reset_start_time
          session.active = false
          session.save!

          # Update user's daily usage
          usage_record = session.user.todays_usage_record
          usage_record.record_session_usage(session)

          stats[:sessions_ended] += 1
          Rails.logger.info "Ended active session for #{session.user.name}"
        rescue => e
          error_msg = "Failed to end session for user #{session.user&.name}: #{e.message}"
          Rails.logger.error error_msg
          stats[:errors] << error_msg
        end
      end

      # Reset daily usage records for all users
      Rails.logger.info "Resetting daily usage records for all users"
      DailyUsage.reset_all_for_new_day(date)
      stats[:allowances_reset] = User.count

      # Reset internet control states for timer-controlled users
      Rails.logger.info "Resetting internet control states"
      InternetControlState.reset_timer_control!
      stats[:internet_controls_reset] = InternetControlState.timer_controlled.count

      # Process each user individually for any custom logic
      User.includes(:multimedia_allowance, :daily_usages, :internet_control_state).find_each do |user|
        begin
          process_user_midnight_reset(user, date, stats)
          stats[:users_processed] += 1
        rescue => e
          error_msg = "Failed to process midnight reset for user #{user.name}: #{e.message}"
          Rails.logger.error error_msg
          stats[:errors] << error_msg
        end
      end

      # Cleanup old records
      cleanup_old_records

      # Log completion
      duration = Time.current - reset_start_time
      Rails.logger.info "Midnight reset completed in #{duration.round(2)} seconds"
      Rails.logger.info "Stats: #{stats.except(:errors)}"
      Rails.logger.warn "Errors: #{stats[:errors]}" if stats[:errors].any?

      # Schedule the next midnight reset
      schedule_next_reset

    rescue => e
      Rails.logger.error "Midnight reset job failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Still try to schedule the next reset even if this one failed
      schedule_next_reset
      raise
    end
  end

  private

  # Process individual user's midnight reset
  def process_user_midnight_reset(user, date, stats)
    # Ensure user has multimedia allowance configured
    allowance = user.ensure_multimedia_allowance

    # Create or update today's usage record
    usage_record = DailyUsage.for_user_on_date(user, date)

    # Reset bonus time if it's configured to reset daily
    if allowance.bonus_time_enabled?
      # Reset any unused bonus time (this could be configurable)
      # For now, we'll let unused bonus time expire at midnight
      usage_record.update!(
        bonus_minutes_earned: 0,
        bonus_minutes_used: 0
      )
    end

    # Check if user should have internet enabled for the new day
    if user.internet_control_state&.timer_controlled?
      # Enable internet for the new day unless manually overridden
      unless user.internet_control_state.manually_overridden?
        InternetControlService.enable_internet(
          user,
          controlled_by: :timer,
          reason: "Daily reset - new day allowance"
        )
      end
    end

    # Log user reset
    Rails.logger.debug "Reset completed for #{user.name}: #{allowance.todays_base_allowance} minutes allowed"
  end

  # Cleanup old records to prevent database bloat
  def cleanup_old_records
    Rails.logger.info "Cleaning up old records"

    # Clean up old multimedia sessions (keep last 90 days)
    old_sessions_count = MultimediaSession.where("started_at < ?", 90.days.ago).count
    MultimediaSession.cleanup_old_sessions if old_sessions_count > 0

    # Clean up old daily usage records (keep last 90 days)
    old_usage_count = DailyUsage.where("usage_date < ?", 90.days.ago).count
    DailyUsage.cleanup_old_records if old_usage_count > 0

    Rails.logger.info "Cleaned up #{old_sessions_count} old sessions and #{old_usage_count} old usage records"
  end

  # Schedule the next midnight reset job
  def schedule_next_reset
    next_midnight = Date.tomorrow.beginning_of_day
    Rails.logger.info "Scheduling next midnight reset for #{next_midnight}"

    # Use Solid Queue's recurring job feature or schedule manually
    MidnightResetJob.set(wait_until: next_midnight).perform_later(Date.tomorrow)
  end
end