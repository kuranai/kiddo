class User < ApplicationRecord
  has_secure_password validations: true

  has_many :assigned_todos, class_name: "Todo", foreign_key: "assignee_id", dependent: :destroy
  has_many :created_todos, class_name: "Todo", foreign_key: "creator_id", dependent: :destroy
  has_many :point_transactions, dependent: :destroy

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

  private

  def downcase_email
    self.email = email&.downcase
  end
end
