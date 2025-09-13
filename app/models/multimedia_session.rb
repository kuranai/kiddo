class MultimediaSession < ApplicationRecord
  belongs_to :user

  enum :session_type, { regular: 0, bonus: 1, emergency: 2 }

  validates :started_at, presence: true
  validates :session_type, presence: true
  validates :active, inclusion: { in: [true, false] }
  validates :duration_minutes, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validate :ended_at_after_started_at, if: :ended_at?
  validate :only_one_active_session_per_user, if: :active?

  scope :active, -> { where(active: true) }
  scope :completed, -> { where(active: false) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_date, ->(date) { where(started_at: date.beginning_of_day..date.end_of_day) }
  scope :recent, -> { order(started_at: :desc) }

  before_save :calculate_duration, if: :ended_at_changed?

  # Check if session is currently running
  def running?
    active? && ended_at.blank?
  end

  # End the current session
  def end_session!
    return false unless running?

    self.ended_at = Time.current
    self.active = false
    calculate_duration
    save!
  end

  # Get session duration in minutes (live calculation for active sessions)
  def current_duration_minutes
    if running?
      ((Time.current - started_at) / 60).to_i
    else
      duration_minutes
    end
  end

  # Get session duration in seconds (for precise timing)
  def current_duration_seconds
    if running?
      (Time.current - started_at).to_i
    else
      duration_minutes * 60
    end
  end

  # Check if session has exceeded a certain duration
  def exceeded_duration?(limit_minutes)
    current_duration_minutes >= limit_minutes
  end

  # Get formatted duration string
  def formatted_duration
    minutes = current_duration_minutes
    hours = minutes / 60
    mins = minutes % 60

    if hours > 0
      "#{hours}h #{mins}m"
    else
      "#{mins}m"
    end
  end

  # Get formatted time remaining (if limit provided)
  def formatted_time_remaining(limit_minutes)
    remaining = limit_minutes - current_duration_minutes
    return "0m" if remaining <= 0

    hours = remaining / 60
    mins = remaining % 60

    if hours > 0
      "#{hours}h #{mins}m"
    else
      "#{mins}m"
    end
  end

  # Check if session is within warning threshold
  def within_warning_threshold?(limit_minutes, warning_minutes = 15)
    remaining = limit_minutes - current_duration_minutes
    remaining <= warning_minutes && remaining > 0
  end

  # Class methods for session management
  class << self
    # Get current active session for user
    def current_for_user(user)
      active.for_user(user).first
    end

    # Start a new session for user
    def start_for_user(user, session_type: :regular)
      # End any existing active sessions
      active.for_user(user).update_all(active: false, ended_at: Time.current)

      create!(
        user: user,
        started_at: Time.current,
        session_type: session_type,
        active: true
      )
    end

    # Get total usage for user on date
    def total_usage_for_date(user, date)
      for_user(user).for_date(date).sum(:duration_minutes)
    end

    # Get daily session summary
    def daily_summary(user, date = Date.current)
      sessions = for_user(user).for_date(date)
      {
        total_sessions: sessions.count,
        total_minutes: sessions.sum(:duration_minutes),
        active_session: sessions.active.first,
        completed_sessions: sessions.completed.count,
        session_types: sessions.group(:session_type).count
      }
    end

    # Clean up old completed sessions (keep last 30 days)
    def cleanup_old_sessions
      where(active: false)
        .where("started_at < ?", 30.days.ago)
        .delete_all
    end
  end

  private

  # Calculate and set duration when session ends
  def calculate_duration
    if ended_at.present? && started_at.present?
      self.duration_minutes = ((ended_at - started_at) / 60).to_i
    end
  end

  # Validation: ended_at must be after started_at
  def ended_at_after_started_at
    return unless ended_at.present? && started_at.present?

    if ended_at <= started_at
      errors.add(:ended_at, "must be after start time")
    end
  end

  # Validation: only one active session per user
  def only_one_active_session_per_user
    existing_active = self.class.active.for_user(user).where.not(id: id)
    if existing_active.exists?
      errors.add(:active, "user can only have one active session at a time")
    end
  end
end