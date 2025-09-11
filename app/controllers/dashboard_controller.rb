class DashboardController < ApplicationController
  def index
    @users = User.all
    @total_family_points = User.sum(:points_balance)

    if current_user.parent?
      # Parent dashboard: family overview
      @recent_todos = Todo.includes(:assignee, :creator).order(created_at: :desc).limit(5)
      @pending_todos_count = Todo.pending.count
      @completed_today_count = Todo.completed.where(completed_at: Date.current.beginning_of_day..Date.current.end_of_day).count
      @available_rewards_count = Reward.active.count
      @family_wide_todos = Todo.family_wide_available.limit(3)
      @active_todos_count = Todo.pending.count
      @my_pending_todos = current_user.assigned_todos.pending.count
      @affordable_rewards = Reward.active.affordable_for(current_user).count
    else
      # Kid dashboard: personal overview
      @my_pending_todos_list = current_user.assigned_todos.pending.limit(5)
      @my_pending_todos = current_user.assigned_todos.pending.count
      @my_recent_completions = current_user.assigned_todos.completed.order(completed_at: :desc).limit(3)
      @affordable_rewards_list = Reward.active.affordable_for(current_user).limit(3)
      @affordable_rewards = Reward.active.affordable_for(current_user).count
      @family_wide_todos = Todo.family_wide_available.limit(3)
      @recent_transactions = current_user.point_transactions.recent.limit(5)
    end
  end
end
