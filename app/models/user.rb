class User < ApplicationRecord
  has_secure_password validations: true

  has_many :assigned_todos, class_name: "Todo", foreign_key: "assignee_id", dependent: :destroy
  has_many :created_todos, class_name: "Todo", foreign_key: "creator_id", dependent: :destroy
  has_many :point_transactions, dependent: :destroy
  has_one :multimedia_allowance, dependent: :destroy
  has_many :multimedia_sessions, dependent: :destroy
  has_many :daily_usages, dependent: :destroy
  has_one :internet_control_state, dependent: :destroy

  enum :role, { kid: 0, parent: 1 }

  validates :name, presence: true, length: { minimum: 2 }
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :points_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_validation :downcase_email

  def can_create_todos_for?(user)
    parent? || self == user
  end

  def can_manage_rewards?
    parent?
  end

  def can_redeem_reward?(reward)
    points_balance >= reward.point_cost
  end

  def add_points(amount, description = nil, todo: nil)
    PointTransactionService.award_points(
      self,
      amount,
      description || "Points added",
      todo: todo
    )
  end

  def deduct_points(amount, description = nil, reward: nil)
    begin
      PointTransactionService.deduct_points(
        self,
        amount,
        description || "Points deducted",
        reward: reward
      )
      true
    rescue PointTransactionService::InsufficientPointsError
      false
    end
  end

  # Multimedia allowance helpers
  def ensure_multimedia_allowance
    multimedia_allowance || create_multimedia_allowance!
  end

  def can_manage_multimedia_for?(user)
    parent? || self == user
  end

  def todays_multimedia_allowance
    ensure_multimedia_allowance.todays_base_allowance
  end

  # Multimedia session helpers
  def current_multimedia_session
    multimedia_sessions.active.first
  end

  def has_active_multimedia_session?
    current_multimedia_session.present?
  end

  def todays_multimedia_usage
    MultimediaSession.total_usage_for_date(self, Date.current)
  end

  def multimedia_time_remaining
    allowance = todays_multimedia_allowance
    used = todays_multimedia_usage
    [allowance - used, 0].max
  end

  def can_start_multimedia_session?
    !has_active_multimedia_session? && multimedia_time_remaining > 0
  end

  def todays_usage_record
    DailyUsage.for_user_today(self)
  end

  # Internet control helpers
  def ensure_internet_control_state
    internet_control_state || create_internet_control_state!
  end

  def internet_enabled?
    ensure_internet_control_state.internet_enabled?
  end

  def internet_disabled?
    !internet_enabled?
  end

  private

  def downcase_email
    self.email = email&.downcase
  end
end
