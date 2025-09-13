class InternetControlState < ApplicationRecord
  belongs_to :user
  belongs_to :manual_override_by, class_name: "User", optional: true

  validates :internet_enabled, inclusion: { in: [true, false] }
  validates :controlled_by_timer, inclusion: { in: [true, false] }
  validates :user_id, uniqueness: true
  validates :override_reason, length: { maximum: 1000 }

  validate :override_by_must_be_parent, if: :manual_override_by_id?
  validate :override_reason_required_for_manual_override, if: :manual_override_by_id?

  scope :enabled, -> { where(internet_enabled: true) }
  scope :disabled, -> { where(internet_enabled: false) }
  scope :timer_controlled, -> { where(controlled_by_timer: true) }
  scope :manually_controlled, -> { where(controlled_by_timer: false) }
  scope :with_overrides, -> { where.not(manual_override_by_id: nil) }

  # Enable internet access for user
  def enable_internet!(controlled_by: nil, override_by: nil, reason: nil)
    update_control_state!(
      internet_enabled: true,
      controlled_by: controlled_by,
      override_by: override_by,
      reason: reason
    )
  end

  # Disable internet access for user
  def disable_internet!(controlled_by: nil, override_by: nil, reason: nil)
    update_control_state!(
      internet_enabled: false,
      controlled_by: controlled_by,
      override_by: override_by,
      reason: reason
    )
  end

  # Check if currently enabled
  def internet_enabled?
    internet_enabled
  end

  # Check if currently disabled
  def internet_disabled?
    !internet_enabled
  end

  # Check if controlled by timer system
  def timer_controlled?
    controlled_by_timer
  end

  # Check if manually overridden by parent
  def manually_overridden?
    manual_override_by_id.present?
  end

  # Clear manual override
  def clear_manual_override!
    update!(
      manual_override_by: nil,
      override_reason: nil,
      last_controlled_at: Time.current
    )
  end

  # Get control status summary
  def status_summary
    {
      enabled: internet_enabled?,
      controlled_by_timer: timer_controlled?,
      manually_overridden: manually_overridden?,
      override_by: manual_override_by&.name,
      override_reason: override_reason,
      last_controlled: last_controlled_at,
      can_be_timer_controlled: !manually_overridden?
    }
  end

  # Get formatted last controlled time
  def formatted_last_controlled
    return "Never" unless last_controlled_at

    if last_controlled_at.today?
      last_controlled_at.strftime("%I:%M %p")
    elsif last_controlled_at >= 1.day.ago
      "Yesterday at #{last_controlled_at.strftime('%I:%M %p')}"
    else
      last_controlled_at.strftime("%m/%d/%Y at %I:%M %p")
    end
  end

  # Class methods for bulk operations
  class << self
    # Find or create control state for user
    def for_user(user)
      find_or_create_by(user: user) do |state|
        state.internet_enabled = true
        state.controlled_by_timer = false
      end
    end

    # Enable internet for multiple users
    def enable_for_users(users, controlled_by: nil, override_by: nil, reason: nil)
      users.each do |user|
        state = for_user(user)
        state.enable_internet!(
          controlled_by: controlled_by,
          override_by: override_by,
          reason: reason
        )
      end
    end

    # Disable internet for multiple users
    def disable_for_users(users, controlled_by: nil, override_by: nil, reason: nil)
      users.each do |user|
        state = for_user(user)
        state.disable_internet!(
          controlled_by: controlled_by,
          override_by: override_by,
          reason: reason
        )
      end
    end

    # Emergency disable all kids' internet
    def emergency_disable_all_kids!(parent, reason = "Emergency override")
      kid_users = User.kid
      disable_for_users(
        kid_users,
        controlled_by: :manual,
        override_by: parent,
        reason: reason
      )
    end

    # Reset timer control for all users (midnight reset)
    def reset_timer_control!
      timer_controlled.find_each do |state|
        # If manually overridden, keep the override
        next if state.manually_overridden?

        # Otherwise, enable internet for new day
        state.enable_internet!(controlled_by: :timer)
      end
    end

    # Get family internet status summary
    def family_status_summary
      states = includes(:user, :manual_override_by)

      {
        total_users: states.count,
        enabled_count: states.enabled.count,
        disabled_count: states.disabled.count,
        timer_controlled_count: states.timer_controlled.count,
        manually_overridden_count: states.with_overrides.count,
        states: states.map(&:status_summary)
      }
    end

    # Clean up old control history (keep last 30 days of logs)
    def cleanup_old_logs
      # This would be implemented if we add a separate control log table
      # For now, we just keep the current state
    end
  end

  private

  # Update control state with proper logging
  def update_control_state!(internet_enabled:, controlled_by: nil, override_by: nil, reason: nil)
    attributes = {
      internet_enabled: internet_enabled,
      last_controlled_at: Time.current
    }

    case controlled_by
    when :timer
      attributes[:controlled_by_timer] = true
      attributes[:manual_override_by] = nil
      attributes[:override_reason] = nil
    when :manual
      attributes[:controlled_by_timer] = false
      attributes[:manual_override_by] = override_by
      attributes[:override_reason] = reason
    end

    update!(attributes)

    # TODO: Trigger actual internet control API call here
    # InternetControlService.apply_control(user, internet_enabled)
  end

  # Validation: override user must be a parent
  def override_by_must_be_parent
    return unless manual_override_by

    unless manual_override_by.parent?
      errors.add(:manual_override_by, "must be a parent user")
    end
  end

  # Validation: require reason for manual overrides
  def override_reason_required_for_manual_override
    if manual_override_by_id.present? && override_reason.blank?
      errors.add(:override_reason, "is required for manual overrides")
    end
  end
end