class ParentControlChannel < ApplicationCable::Channel
  def subscribed
    # Only parents can subscribe to this channel
    if current_user&.parent?
      stream_for current_user
      Rails.logger.info "Parent #{current_user.name} subscribed to parent control channel"

      # Send initial family status on connection
      transmit_family_status
    else
      Rails.logger.warn "Non-parent attempted to subscribe to parent control channel: #{current_user&.name}"
      reject
    end
  end

  def unsubscribed
    Rails.logger.info "Parent #{current_user&.name} unsubscribed from parent control channel"
  end

  # Handle family status request
  def get_family_status(data)
    return reject unless current_user&.parent?
    transmit_family_status
  end

  # Handle emergency stop for a specific child
  def emergency_stop(data)
    return reject unless current_user&.parent?

    child_id = data["child_id"]
    reason = data["reason"] || "Emergency stop by parent"

    begin
      child = User.find(child_id)

      # Force stop the child's session
      session = MultimediaTimerService.force_stop_session(
        child,
        stopped_by: current_user,
        reason: reason
      )

      # Broadcast success to parent
      broadcast_to_parent({
        type: :emergency_stop_success,
        child_id: child.id,
        child_name: child.name,
        reason: reason,
        message: "Emergency stop successful for #{child.name}"
      })

      # Notify the child via their timer channel
      TimerChannel.broadcast_force_stopped(child, current_user, reason)

      Rails.logger.info "Emergency stop executed by #{current_user.name} for #{child.name}: #{reason}"

    rescue ActiveRecord::RecordNotFound
      broadcast_error("Child user not found")
    rescue => e
      Rails.logger.error "Emergency stop failed: #{e.message}"
      broadcast_error("Emergency stop failed: #{e.message}")
    end
  end

  # Handle emergency session start for a child
  def start_emergency_session(data)
    return reject unless current_user&.parent?

    child_id = data["child_id"]
    reason = data["reason"] || "Emergency session by parent"
    duration = (data["duration"] || 30).to_i

    begin
      child = User.find(child_id)

      # Start emergency session
      session = MultimediaTimerService.start_emergency_session(
        child,
        parent: current_user,
        reason: reason,
        duration_minutes: duration
      )

      # Broadcast success to parent
      broadcast_to_parent({
        type: :emergency_session_started,
        child_id: child.id,
        child_name: child.name,
        duration_minutes: duration,
        reason: reason,
        message: "Emergency session started for #{child.name}"
      })

      # Notify the child via their timer channel
      TimerChannel.broadcast_emergency_started(child, current_user, reason)

      Rails.logger.info "Emergency session started by #{current_user.name} for #{child.name}: #{reason}"

    rescue ActiveRecord::RecordNotFound
      broadcast_error("Child user not found")
    rescue => e
      Rails.logger.error "Emergency session start failed: #{e.message}"
      broadcast_error("Emergency session start failed: #{e.message}")
    end
  end

  # Handle internet control for a child
  def control_internet(data)
    return reject unless current_user&.parent?

    child_id = data["child_id"]
    action = data["action"] # "enable" or "disable"
    reason = data["reason"] || "Parent manual control"

    begin
      child = User.find(child_id)

      # Queue internet control job
      if action == "enable"
        InternetControlJob.enable_internet_async(
          child,
          controlled_by: current_user,
          reason: reason
        )
      elsif action == "disable"
        InternetControlJob.disable_internet_async(
          child,
          controlled_by: current_user,
          reason: reason
        )
      else
        broadcast_error("Invalid internet control action: #{action}")
        return
      end

      # Broadcast pending status to parent
      broadcast_to_parent({
        type: :internet_control_pending,
        child_id: child.id,
        child_name: child.name,
        action: action,
        reason: reason,
        message: "Internet control request submitted for #{child.name}"
      })

      Rails.logger.info "Internet control #{action} requested by #{current_user.name} for #{child.name}"

    rescue ActiveRecord::RecordNotFound
      broadcast_error("Child user not found")
    rescue => e
      Rails.logger.error "Internet control request failed: #{e.message}"
      broadcast_error("Internet control request failed: #{e.message}")
    end
  end

  # Handle bulk internet control for multiple children
  def bulk_internet_control(data)
    return reject unless current_user&.parent?

    child_ids = data["child_ids"] || []
    action = data["action"] # "enable" or "disable"
    reason = data["reason"] || "Parent bulk control"

    begin
      children = User.where(id: child_ids, role: :kid)

      if action == "enable"
        InternetControlJob.bulk_enable_async(children)
      elsif action == "disable"
        InternetControlJob.bulk_disable_async(children)
      else
        broadcast_error("Invalid bulk action: #{action}")
        return
      end

      # Broadcast pending status to parent
      broadcast_to_parent({
        type: :bulk_internet_control_pending,
        child_count: children.count,
        action: action,
        reason: reason,
        message: "Bulk internet control request submitted for #{children.count} children"
      })

      Rails.logger.info "Bulk internet #{action} requested by #{current_user.name} for #{children.count} children"

    rescue => e
      Rails.logger.error "Bulk internet control failed: #{e.message}"
      broadcast_error("Bulk internet control failed: #{e.message}")
    end
  end

  # Handle bonus time award for a child
  def award_bonus_time(data)
    return reject unless current_user&.parent?

    child_id = data["child_id"]
    minutes = data["minutes"].to_i
    reason = data["reason"] || "Parent bonus award"

    begin
      child = User.find(child_id)

      # Award bonus time
      actual_bonus = MultimediaTimerService.add_bonus_time(child, minutes, reason)

      # Broadcast result to parent
      broadcast_to_parent({
        type: :bonus_time_awarded,
        child_id: child.id,
        child_name: child.name,
        requested_minutes: minutes,
        actual_minutes: actual_bonus,
        reason: reason,
        message: "Awarded #{actual_bonus} minutes of bonus time to #{child.name}"
      })

      # Notify the child if bonus was awarded
      if actual_bonus > 0
        TimerChannel.broadcast_bonus_awarded(child, actual_bonus, reason)
      end

      Rails.logger.info "Bonus time awarded by #{current_user.name} to #{child.name}: #{actual_bonus} minutes"

    rescue ActiveRecord::RecordNotFound
      broadcast_error("Child user not found")
    rescue => e
      Rails.logger.error "Bonus time award failed: #{e.message}"
      broadcast_error("Bonus time award failed: #{e.message}")
    end
  end

  private

  # Send current family status to the parent
  def transmit_family_status
    family_data = gather_family_status

    transmit({
      type: :family_status,
      **family_data,
      timestamp: Time.current.iso8601
    })
  end

  # Gather comprehensive family status data
  def gather_family_status
    children = User.kid.includes(
      :multimedia_sessions,
      :daily_usages,
      :internet_control_state,
      :multimedia_allowance
    )

    family_status = {
      total_children: children.count,
      active_sessions: 0,
      children_status: []
    }

    children.each do |child|
      status = MultimediaTimerService.get_session_status(child)
      usage_record = child.todays_usage_record

      child_status = {
        id: child.id,
        name: child.name,
        has_active_session: status[:has_active_session],
        session_duration: status[:session_duration],
        remaining_minutes: status[:remaining_minutes],
        daily_usage: status[:daily_usage],
        daily_allowance: status[:daily_allowance],
        usage_percentage: status[:usage_percentage],
        internet_enabled: status[:internet_enabled],
        time_exhausted: status[:time_exhausted],
        last_activity: child.multimedia_sessions.maximum(:started_at),
        can_start_session: status[:can_start_session]
      }

      family_status[:children_status] << child_status
      family_status[:active_sessions] += 1 if status[:has_active_session]
    end

    # Add family-wide statistics
    family_status[:family_stats] = {
      total_usage_today: family_status[:children_status].sum { |c| c[:daily_usage] },
      total_allowance_today: family_status[:children_status].sum { |c| c[:daily_allowance] },
      children_with_time_remaining: family_status[:children_status].count { |c| c[:remaining_minutes] > 0 },
      children_internet_enabled: family_status[:children_status].count { |c| c[:internet_enabled] }
    }

    family_status
  end

  # Broadcast message to the current parent
  def broadcast_to_parent(message)
    ParentControlChannel.broadcast_to(current_user, message.merge(
      timestamp: Time.current.iso8601,
      parent_id: current_user.id
    ))
  end

  # Broadcast error message
  def broadcast_error(error_message)
    broadcast_to_parent({
      type: :error,
      error: error_message,
      message: "Operation failed: #{error_message}"
    })
  end

  # Class methods for broadcasting from services/jobs
  class << self
    # Broadcast family alert to all parents
    def broadcast_family_alert(alert_type, message, data = {})
      parents = User.parent.includes(:children)

      parents.each do |parent|
        broadcast_to(parent, {
          type: :family_alert,
          alert_type: alert_type,
          message: message,
          data: data,
          timestamp: Time.current.iso8601,
          parent_id: parent.id
        })
      end
    end

    # Broadcast child session event to their parents
    def broadcast_child_event(child, event_type, message, data = {})
      # For now, broadcast to all parents
      # Could be enhanced to only broadcast to specific child's parents
      parents = User.parent

      parents.each do |parent|
        broadcast_to(parent, {
          type: :child_event,
          event_type: event_type,
          child_id: child.id,
          child_name: child.name,
          message: message,
          data: data,
          timestamp: Time.current.iso8601,
          parent_id: parent.id
        })
      end
    end

    # Broadcast system status to parents
    def broadcast_system_status(status_type, message, data = {})
      parents = User.parent

      parents.each do |parent|
        broadcast_to(parent, {
          type: :system_status,
          status_type: status_type,
          message: message,
          data: data,
          timestamp: Time.current.iso8601,
          parent_id: parent.id
        })
      end
    end

    # Broadcast internet control result to parent
    def broadcast_internet_control_result(parent, child, action, success, message)
      broadcast_to(parent, {
        type: :internet_control_result,
        child_id: child.id,
        child_name: child.name,
        action: action,
        success: success,
        message: message,
        timestamp: Time.current.iso8601,
        parent_id: parent.id
      })
    end
  end
end