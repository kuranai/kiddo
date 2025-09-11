class PointTransactionService
  class InsufficientPointsError < StandardError; end
  class InvalidAmountError < StandardError; end

  def self.award_points(user, amount, description, todo: nil)
    new.award_points(user, amount, description, todo: todo)
  end

  def self.deduct_points(user, amount, description, reward: nil)
    new.deduct_points(user, amount, description, reward: reward)
  end

  def award_points(user, amount, description, todo: nil)
    validate_amount!(amount)
    validate_user!(user)

    ActiveRecord::Base.transaction do
      user.increment!(:points_balance, amount)

      transaction = user.point_transactions.create!(
        amount: amount,
        description: description,
        transaction_type: :earning,
        todo: todo
      )

      Rails.logger.info "Awarded #{amount} points to #{user.name} (ID: #{user.id}). New balance: #{user.points_balance}"

      transaction
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to award points: #{e.message}"
    raise e
  end

  def deduct_points(user, amount, description, reward: nil)
    validate_amount!(amount)
    validate_user!(user)

    if user.points_balance < amount
      raise InsufficientPointsError, "User #{user.name} has insufficient points. Balance: #{user.points_balance}, Required: #{amount}"
    end

    ActiveRecord::Base.transaction do
      user.decrement!(:points_balance, amount)

      transaction = user.point_transactions.create!(
        amount: -amount,
        description: description,
        transaction_type: :spending,
        reward: reward
      )

      Rails.logger.info "Deducted #{amount} points from #{user.name} (ID: #{user.id}). New balance: #{user.points_balance}"

      transaction
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to deduct points: #{e.message}"
    raise e
  end

  private

  def validate_amount!(amount)
    unless amount.is_a?(Numeric) && amount > 0
      raise InvalidAmountError, "Amount must be a positive number, got: #{amount}"
    end
  end

  def validate_user!(user)
    unless user.is_a?(User) && user.persisted?
      raise ArgumentError, "Invalid user provided"
    end
  end
end
