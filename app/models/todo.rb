class Todo < ApplicationRecord
  belongs_to :assignee, class_name: "User", optional: true
  belongs_to :creator, class_name: "User"
  has_many :point_transactions, dependent: :destroy

  validates :title, presence: true, length: { minimum: 2, maximum: 255 }
  validates :points, presence: true, numericality: { greater_than: 0 }
  validates :assignee_id, presence: true, unless: :family_wide?
  validates :creator_id, presence: true

  enum :recurring_type, { daily: 0, weekly: 1, monthly: 2 }

  scope :completed, -> { where(completed: true) }
  scope :pending, -> { where(completed: false) }
  scope :overdue, -> { where("due_date < ? AND completed = ?", Time.current, false) }
  scope :family_wide, -> { where(family_wide: true) }
  scope :family_wide_available, -> { where(family_wide: true, completed: false) }
  scope :assigned_to, ->(user) { where(assignee: user) }
  scope :created_by, ->(user) { where(creator: user) }

  def completable_by?(user)
    return false if completed?

    if family_wide?
      true
    else
      assignee == user
    end
  end

  def complete!(completing_user)
    return false unless completable_by?(completing_user)

    transaction do
      update!(
        completed: true,
        completed_at: Time.current,
        assignee: completing_user
      )

      PointTransactionService.award_points(
        completing_user,
        points,
        "Completed: #{title}",
        todo: self
      )
    end
  end

  def overdue?
    due_date.present? && due_date < Time.current && !completed?
  end

  def generate_next_occurrence
    return unless recurring? && recurring_type.present?

    next_due_date = case recurring_type.to_sym
    when :daily
      1.day.from_now
    when :weekly
      1.week.from_now
    when :monthly
      1.month.from_now
    end

    Todo.create!(
      title: title,
      description: description,
      points: points,
      assignee: assignee,
      creator: creator,
      due_date: next_due_date,
      recurring: recurring,
      recurring_type: recurring_type,
      recurring_days: recurring_days,
      family_wide: family_wide
    )
  end
end
