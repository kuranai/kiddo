class RecurringTodoJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "RecurringTodoJob started at #{Time.current}"

    todos_created = 0

    # Find completed recurring todos that need new instances
    completed_recurring_todos = Todo.where(
      completed: true,
      recurring: true
    ).where.not(recurring_type: nil)

    Rails.logger.info "Found #{completed_recurring_todos.count} completed recurring todos to process"

    completed_recurring_todos.find_each do |todo|
      begin
        # Check if we should create a new occurrence
        if should_create_next_occurrence?(todo)
          new_todo = todo.generate_next_occurrence
          if new_todo.persisted?
            todos_created += 1
            Rails.logger.info "Created new recurring todo: #{new_todo.title} (ID: #{new_todo.id})"
          else
            Rails.logger.error "Failed to create recurring todo: #{new_todo.errors.full_messages.join(', ')}"
          end
        end
      rescue => e
        Rails.logger.error "Error processing recurring todo #{todo.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    Rails.logger.info "RecurringTodoJob completed. Created #{todos_created} new todos."
  end

  private

  def should_create_next_occurrence?(todo)
    return false unless todo.completed? && todo.recurring?

    # Check if a new occurrence already exists for this recurring todo
    next_due_date = calculate_next_due_date(todo)
    return false if next_due_date.blank?

    # Look for existing todos that would be the "next occurrence"
    # We check for todos with the same title, assignee, and creator that are due around the next due date
    existing_next_occurrence = Todo.where(
      title: todo.title,
      assignee: todo.assignee,
      creator: todo.creator,
      recurring: true,
      recurring_type: todo.recurring_type,
      completed: false
    ).where(
      due_date: (next_due_date - 1.hour)..(next_due_date + 1.hour)
    ).exists?

    !existing_next_occurrence
  end

  def calculate_next_due_date(todo)
    return nil unless todo.recurring_type.present?

    # Base the next occurrence on when the todo was completed
    base_date = todo.completed_at || todo.due_date || Time.current

    case todo.recurring_type.to_sym
    when :daily
      base_date + 1.day
    when :weekly
      base_date + 1.week
    when :monthly
      base_date + 1.month
    else
      nil
    end
  end
end
