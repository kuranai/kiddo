class Reward < ApplicationRecord
  has_many :point_transactions, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 255 }
  validates :point_cost, presence: true, numericality: { greater_than: 0 }
  validates :active, inclusion: { in: [true, false] }

  scope :active, -> { where(active: true) }
  scope :affordable_for, ->(user) { where('point_cost <= ?', user.points_balance) }

  def affordable_by?(user)
    user.points_balance >= point_cost
  end

  def redeem_for!(user)
    return false unless affordable_by?(user) && active?
    
    transaction do
      user.deduct_points(point_cost, "Redeemed: #{name}", reward: self)
    end
  end
end
