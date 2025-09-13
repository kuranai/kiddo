class InternetControlJob < ApplicationJob
  queue_as :default

  retry_on InternetControlService::APIConnectionError, wait: :exponentially_longer, attempts: 3
  retry_on InternetControlService::InternetControlError, wait: 30.seconds, attempts: 2

  discard_on InternetControlService::AuthenticationError
  discard_on InternetControlService::UnsupportedRouterError

  # Perform internet control operation asynchronously
  def perform(user_id, action, controlled_by_id: nil, reason: nil, retry_count: 0)
    user = User.find(user_id)
    controlled_by = controlled_by_id ? User.find(controlled_by_id) : nil

    Rails.logger.info "Internet control job: #{action} for #{user.name} (attempt #{retry_count + 1})"

    begin
      case action.to_s
      when "enable"
        handle_enable_internet(user, controlled_by, reason)
      when "disable"
        handle_disable_internet(user, controlled_by, reason)
      when "check_status"
        handle_status_check(user)
      when "bulk_enable"
        handle_bulk_enable(user_id) # user_id is actually array of user IDs in this case
      when "bulk_disable"
        handle_bulk_disable(user_id) # user_id is actually array of user IDs in this case
      else
        raise ArgumentError, "Unknown internet control action: #{action}"
      end

    rescue InternetControlService::InternetControlError => e
      handle_control_error(user, action, e, retry_count)
      raise # Let retry logic handle it
    rescue => e
      Rails.logger.error "Internet control job failed for #{user.name}: #{e.message}"
      handle_unexpected_error(user, action, e)
      raise
    end
  end

  private

  # Handle enabling internet for a user
  def handle_enable_internet(user, controlled_by, reason)
    Rails.logger.info "Enabling internet for #{user.name}"

    success = InternetControlService.enable_internet(
      user,
      controlled_by: controlled_by,
      reason: reason
    )

    if success
      # Update internet control state
      internet_state = user.ensure_internet_control_state
      if controlled_by
        internet_state.enable_internet!(
          controlled_by: :manual,
          override_by: controlled_by,
          reason: reason
        )
      else
        internet_state.enable_internet!(controlled_by: :timer, reason: reason)
      end

      # Broadcast success
      broadcast_control_result(user, :enable, :success, reason)

      Rails.logger.info "Successfully enabled internet for #{user.name}"
    else
      raise InternetControlService::InternetControlError, "Failed to enable internet"
    end
  end

  # Handle disabling internet for a user
  def handle_disable_internet(user, controlled_by, reason)
    Rails.logger.info "Disabling internet for #{user.name}"

    success = InternetControlService.disable_internet(
      user,
      controlled_by: controlled_by,
      reason: reason
    )

    if success
      # Update internet control state
      internet_state = user.ensure_internet_control_state
      if controlled_by
        internet_state.disable_internet!(
          controlled_by: :manual,
          override_by: controlled_by,
          reason: reason
        )
      else
        internet_state.disable_internet!(controlled_by: :timer, reason: reason)
      end

      # Broadcast success
      broadcast_control_result(user, :disable, :success, reason)

      Rails.logger.info "Successfully disabled internet for #{user.name}"
    else
      raise InternetControlService::InternetControlError, "Failed to disable internet"
    end
  end

  # Handle status check for a user
  def handle_status_check(user)
    Rails.logger.debug "Checking internet status for #{user.name}"

    status = InternetControlService.check_internet_status(user)

    # Update local state if there's a discrepancy
    internet_state = user.ensure_internet_control_state
    if internet_state.internet_enabled? != status[:enabled]
      Rails.logger.warn "Internet status mismatch for #{user.name}: local=#{internet_state.internet_enabled?}, actual=#{status[:enabled]}"

      # Update local state to match actual status
      if status[:enabled]
        internet_state.enable_internet!(controlled_by: :timer, reason: "Status sync")
      else
        internet_state.disable_internet!(controlled_by: :timer, reason: "Status sync")
      end
    end

    # Broadcast status update
    broadcast_status_update(user, status)

    status
  end

  # Handle bulk enable for multiple users
  def handle_bulk_enable(user_ids)
    Rails.logger.info "Bulk enabling internet for #{user_ids.count} users"

    results = []
    user_ids.each do |user_id|
      begin
        user = User.find(user_id)
        handle_enable_internet(user, nil, "Bulk enable operation")
        results << { user_id: user_id, success: true }
      rescue => e
        Rails.logger.error "Bulk enable failed for user #{user_id}: #{e.message}"
        results << { user_id: user_id, success: false, error: e.message }
      end
    end

    # Broadcast bulk operation result
    broadcast_bulk_result(:enable, results)

    results
  end

  # Handle bulk disable for multiple users
  def handle_bulk_disable(user_ids)
    Rails.logger.info "Bulk disabling internet for #{user_ids.count} users"

    results = []
    user_ids.each do |user_id|
      begin
        user = User.find(user_id)
        handle_disable_internet(user, nil, "Bulk disable operation")
        results << { user_id: user_id, success: true }
      rescue => e
        Rails.logger.error "Bulk disable failed for user #{user_id}: #{e.message}"
        results << { user_id: user_id, success: false, error: e.message }
      end
    end

    # Broadcast bulk operation result
    broadcast_bulk_result(:disable, results)

    results
  end

  # Handle control errors with appropriate logging and notifications
  def handle_control_error(user, action, error, retry_count)
    error_type = error.class.name.demodulize

    Rails.logger.error "Internet control error for #{user.name} (#{action}): #{error_type} - #{error.message}"

    # Determine if we should notify parents about the error
    should_notify_parents = retry_count >= 2 || error.is_a?(InternetControlService::AuthenticationError)

    if should_notify_parents
      notify_parents_of_control_error(user, action, error)
    end

    # Broadcast error to user
    broadcast_control_result(user, action, :error, error.message)

    # For certain errors, try fallback methods
    if error.is_a?(InternetControlService::APIConnectionError)
      attempt_fallback_control(user, action)
    end
  end

  # Handle unexpected errors
  def handle_unexpected_error(user, action, error)
    Rails.logger.error "Unexpected error in internet control for #{user.name}: #{error.class} - #{error.message}"
    Rails.logger.error error.backtrace.join("\n")

    # Notify parents of system error
    notify_parents_of_system_error(user, action, error)

    # Broadcast system error
    broadcast_control_result(user, action, :system_error, "System error occurred")
  end

  # Attempt fallback control methods when primary method fails
  def attempt_fallback_control(user, action)
    Rails.logger.info "Attempting fallback internet control for #{user.name}: #{action}"

    # TODO: Implement fallback strategies:
    # 1. Try alternative router APIs
    # 2. Use DNS-based blocking (Pi-hole)
    # 3. Use device-specific controls
    # 4. Manual notification to parents

    # For now, just log the attempt
    Rails.logger.warn "Fallback control not implemented - manual intervention may be required"
  end

  # Broadcast control operation result
  def broadcast_control_result(user, action, status, message)
    TimerChannel.broadcast_internet_status(user, action == :enable && status == :success, message)
    Rails.logger.info "Broadcasting #{action} #{status} to #{user.name}: #{message}"
  end

  # Broadcast status update
  def broadcast_status_update(user, status)
    # TODO: Implement ActionCable broadcasting
    # InternetControlChannel.broadcast_to(user, {
    #   type: :status_update,
    #   status: status,
    #   timestamp: Time.current
    # })

    Rails.logger.debug "Broadcasting status update to #{user.name}"
  end

  # Broadcast bulk operation result
  def broadcast_bulk_result(action, results)
    # TODO: Implement ActionCable broadcasting to parents
    # ParentControlChannel.broadcast({
    #   type: :bulk_result,
    #   action: action,
    #   results: results,
    #   timestamp: Time.current
    # })

    success_count = results.count { |r| r[:success] }
    total_count = results.count

    Rails.logger.info "Bulk #{action} completed: #{success_count}/#{total_count} successful"
  end

  # Notify parents of control errors
  def notify_parents_of_control_error(user, action, error)
    # TODO: Implement parent notification system
    # This could be via:
    # 1. ActionCable real-time notifications
    # 2. Email notifications
    # 3. SMS notifications
    # 4. In-app notification center

    Rails.logger.warn "Parent notification needed: Internet control error for #{user.name}"
  end

  # Notify parents of system errors
  def notify_parents_of_system_error(user, action, error)
    # TODO: Implement parent notification for system errors
    Rails.logger.error "System error notification needed for #{user.name}: #{error.class}"
  end

  # Class methods for easy job scheduling
  class << self
    def enable_internet_async(user, controlled_by: nil, reason: nil)
      perform_later(user.id, :enable, controlled_by_id: controlled_by&.id, reason: reason)
    end

    def disable_internet_async(user, controlled_by: nil, reason: nil)
      perform_later(user.id, :disable, controlled_by_id: controlled_by&.id, reason: reason)
    end

    def check_status_async(user)
      perform_later(user.id, :check_status)
    end

    def bulk_enable_async(users)
      user_ids = users.is_a?(Array) ? users.map(&:id) : [users.id]
      perform_later(user_ids, :bulk_enable)
    end

    def bulk_disable_async(users)
      user_ids = users.is_a?(Array) ? users.map(&:id) : [users.id]
      perform_later(user_ids, :bulk_disable)
    end
  end
end