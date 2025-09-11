class PointTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :todo, optional: true
  belongs_to :reward, optional: true

  validates :amount, presence: true, numericality: true
  validates :description, presence: true, length: { minimum: 2, maximum: 500 }
  validates :transaction_type, presence: true

  enum :transaction_type, { earning: 0, spending: 1 }

  scope :earnings, -> { where(transaction_type: :earning) }
  scope :spendings, -> { where(transaction_type: :spending) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
end
