class DailyUsage < ApplicationRecord
  belongs_to :user

  validates :usage_date, presence: true, uniqueness: { scope: :user_id }
  validates :total_minutes_used, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_minutes_allowed, presence: true, numericality: { greater_than: 0 }
  validates :bonus_minutes_earned, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :bonus_minutes_used, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :remaining_minutes, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validate :bonus_minutes_used_not_exceed_earned
  validate :total_used_not_exceed_total_available

  scope :for_user, ->(user) { where(user: user) }
  scope :for_date, ->(date) { where(usage_date: date) }
  scope :recent, -> { order(usage_date: :desc) }
  scope :current_week, -> { where(usage_date: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :current_month, -> { where(usage_date: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :with_remaining_time, -> { where("remaining_minutes > 0") }
  scope :exhausted, -> { where(remaining_minutes: 0) }

  before_save :calculate_remaining_minutes

  # Calculate total available minutes (base + bonus)
  def total_available_minutes
    total_minutes_allowed + bonus_minutes_earned
  end

  # Calculate total minutes actually used (regular + bonus)
  def actual_total_used
    total_minutes_used + bonus_minutes_used
  end

  # Check if user has time remaining today
  def has_time_remaining?
    remaining_minutes > 0
  end

  # Check if user has exhausted their daily allowance
  def time_exhausted?
    remaining_minutes <= 0
  end

  # Check if user is within warning threshold
  def within_warning_threshold?(warning_minutes = 15)
    remaining_minutes <= warning_minutes && remaining_minutes > 0
  end

  # Get percentage of time used
  def usage_percentage
    return 100 if total_available_minutes == 0

    (actual_total_used.to_f / total_available_minutes * 100).round(1)
  end

  # Get formatted remaining time string
  def formatted_remaining_time
    format_minutes(remaining_minutes)
  end

  # Get formatted total used time string
  def formatted_total_used
    format_minutes(actual_total_used)
  end

  # Get formatted total available time string
  def formatted_total_available
    format_minutes(total_available_minutes)
  end

  # Update usage with new session data
  def record_session_usage(session)
    return unless session.is_a?(MultimediaSession) && session.user == user

    if session.bonus?
      self.bonus_minutes_used += session.duration_minutes
    else
      self.total_minutes_used += session.duration_minutes
    end

    self.last_session_ended_at = session.ended_at || Time.current
    calculate_remaining_minutes
    save!
  end

  # Add bonus time (from todo completion, etc.)
  def add_bonus_time(minutes, max_bonus = nil)
    max_bonus ||= user.ensure_multimedia_allowance.max_bonus_minutes

    new_bonus = bonus_minutes_earned + minutes
    self.bonus_minutes_earned = [new_bonus, max_bonus].min

    calculate_remaining_minutes
    save!
  end

  # Reset daily usage (called at midnight)
  def reset_for_new_day!
    allowance = user.ensure_multimedia_allowance

    update!(
      total_minutes_used: 0,
      total_minutes_allowed: allowance.todays_base_allowance,
      bonus_minutes_earned: 0,
      bonus_minutes_used: 0,
      remaining_minutes: allowance.todays_base_allowance,
      last_session_ended_at: nil
    )
  end

  # Class methods for aggregate operations
  class << self
    # Find or create today's usage record for user
    def for_user_today(user)
      find_or_create_by(user: user, usage_date: Date.current) do |usage|
        allowance = user.ensure_multimedia_allowance
        usage.total_minutes_allowed = allowance.todays_base_allowance
        usage.remaining_minutes = allowance.todays_base_allowance
      end
    end

    # Find or create usage record for specific date
    def for_user_on_date(user, date)
      find_or_create_by(user: user, usage_date: date) do |usage|
        allowance = user.ensure_multimedia_allowance
        base_allowance = allowance.minutes_for_day(date.wday)
        usage.total_minutes_allowed = base_allowance
        usage.remaining_minutes = base_allowance
      end
    end

    # Get weekly summary for user
    def weekly_summary(user, start_date = Date.current.beginning_of_week)
      end_date = start_date.end_of_week
      usages = for_user(user).where(usage_date: start_date..end_date)

      {
        total_days: 7,
        recorded_days: usages.count,
        total_minutes_used: usages.sum(:total_minutes_used),
        total_bonus_used: usages.sum(:bonus_minutes_used),
        total_allowed: usages.sum(:total_minutes_allowed),
        total_bonus_earned: usages.sum(:bonus_minutes_earned),
        days_exhausted: usages.exhausted.count,
        average_daily_usage: usages.count > 0 ? usages.average(:total_minutes_used).to_f.round(1) : 0
      }
    end

    # Get usage trends (last 30 days)
    def usage_trends(user, days = 30)
      end_date = Date.current
      start_date = end_date - days.days

      for_user(user)
        .where(usage_date: start_date..end_date)
        .order(:usage_date)
        .pluck(:usage_date, :total_minutes_used, :remaining_minutes)
        .map do |date, used, remaining|
          {
            date: date,
            minutes_used: used,
            remaining_minutes: remaining,
            percentage_used: remaining > 0 ? (used.to_f / (used + remaining) * 100).round(1) : 100
          }
        end
    end

    # Clean up old records (keep last 90 days)
    def cleanup_old_records
      where("usage_date < ?", 90.days.ago).delete_all
    end

    # Bulk reset for new day (used by background job)
    def reset_all_for_new_day(date = Date.current)
      # Update existing records for the date
      where(usage_date: date).find_each do |usage|
        usage.reset_for_new_day!
      end

      # Create new records for users who don't have one yet
      User.includes(:multimedia_allowance).find_each do |user|
        next if exists?(user: user, usage_date: date)

        allowance = user.ensure_multimedia_allowance
        create!(
          user: user,
          usage_date: date,
          total_minutes_allowed: allowance.minutes_for_day(date.wday),
          remaining_minutes: allowance.minutes_for_day(date.wday)
        )
      end
    end
  end

  private

  # Calculate remaining minutes based on usage and allowances
  def calculate_remaining_minutes
    total_available = total_available_minutes
    total_used = actual_total_used
    self.remaining_minutes = [total_available - total_used, 0].max
  end

  # Format minutes into human-readable string
  def format_minutes(minutes)
    return "0m" if minutes <= 0

    hours = minutes / 60
    mins = minutes % 60

    if hours > 0
      "#{hours}h #{mins}m"
    else
      "#{mins}m"
    end
  end

  # Validation: bonus minutes used cannot exceed bonus minutes earned
  def bonus_minutes_used_not_exceed_earned
    if bonus_minutes_used > bonus_minutes_earned
      errors.add(:bonus_minutes_used, "cannot exceed bonus minutes earned")
    end
  end

  # Validation: total used cannot exceed total available
  def total_used_not_exceed_total_available
    if actual_total_used > total_available_minutes
      errors.add(:total_minutes_used, "total usage cannot exceed total available time")
    end
  end
end