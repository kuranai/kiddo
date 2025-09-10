class User < ApplicationRecord
  has_secure_password validations: true

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

  def add_points(amount, description = nil)
    increment!(:points_balance, amount)
    # TODO: Create PointTransaction record
  end

  def deduct_points(amount, description = nil)
    if points_balance >= amount
      decrement!(:points_balance, amount)
      # TODO: Create PointTransaction record
      true
    else
      false
    end
  end

  private

  def downcase_email
    self.email = email&.downcase
  end
end
