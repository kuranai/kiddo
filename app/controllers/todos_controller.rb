class TodosController < ApplicationController
  before_action :set_todo, only: [ :show, :edit, :update, :destroy, :complete, :unclaim ]
  before_action :authorize_todo_access!, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_todo_creation!, only: [ :new, :create ]

  def index
    @todos = filter_todos
    @filter_type = params[:filter] || "all"
  end

  def show
  end

  def new
    @todo = Todo.new
    @assignable_users = assignable_users_for_current_user
  end

  def create
    @todo = Todo.new(todo_params)
    @todo.creator = current_user
    
    # For family-wide todos, ensure assignee_id is nil, not empty string
    if @todo.family_wide? && @todo.assignee_id.blank?
      @todo.assignee_id = nil
    end

    if @todo.save
      redirect_to todos_path, notice: "Todo '#{@todo.title}' was created successfully!"
    else
      @assignable_users = assignable_users_for_current_user
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @assignable_users = assignable_users_for_current_user
  end

  def update
    # Handle family-wide todos assignee logic
    params_to_update = todo_params
    if params_to_update[:family_wide] == "1" && params_to_update[:assignee_id].blank?
      params_to_update[:assignee_id] = nil
    end
    
    if @todo.update(params_to_update)
      redirect_to todos_path, notice: "Todo '#{@todo.title}' was updated successfully!"
    else
      @assignable_users = assignable_users_for_current_user
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    title = @todo.title
    @todo.destroy
    redirect_to todos_path, notice: "Todo '#{title}' was deleted successfully!"
  end

  def complete
    if @todo.completable_by?(current_user)
      @todo.complete!(current_user)
      redirect_to todos_path, notice: "Great job! You completed '#{@todo.title}' and earned #{@todo.points} points!"
    else
      redirect_to todos_path, alert: "You cannot complete this todo."
    end
  end

  def claim
    @todo = Todo.find(params[:id])

    if @todo.family_wide? && !@todo.completed?
      if @todo.assignee.nil?
        @todo.update!(assignee: current_user)
        redirect_to todos_path, notice: "You claimed '#{@todo.title}'! Complete it to earn #{@todo.points} points."
      else
        redirect_to todos_path, alert: "This todo has already been claimed by #{@todo.assignee.name}."
      end
    else
      redirect_to todos_path, alert: "This todo cannot be claimed."
    end
  end

  def unclaim
    if @todo.family_wide? && @todo.assignee == current_user && !@todo.completed?
      @todo.update!(assignee: nil)
      redirect_to todos_path, notice: "You unclaimed '#{@todo.title}'. It's now available for others to claim."
    else
      redirect_to todos_path, alert: "You cannot unclaim this todo."
    end
  end

  private

  def set_todo
    @todo = Todo.find(params[:id])
  end

  def todo_params
    params.require(:todo).permit(:title, :description, :points, :assignee_id, :due_date,
                                 :recurring, :recurring_type, :recurring_days, :family_wide)
  end

  def filter_todos
    case params[:filter]
    when "mine"
      current_user.assigned_todos
    when "created_by_me"
      current_user.created_todos
    when "completed"
      Todo.completed.where(assignee: accessible_users)
    when "pending"
      Todo.pending.where(assignee: accessible_users)
    when "overdue"
      Todo.overdue.where(assignee: accessible_users)
    when "family_wide"
      Todo.family_wide_available
    else
      # 'all' - show todos for users the current user can see
      Todo.where(assignee: accessible_users).or(Todo.family_wide)
    end.includes(:assignee, :creator).order(created_at: :desc)
  end

  def accessible_users
    if current_user.parent?
      User.all
    else
      [ current_user ]
    end
  end

  def assignable_users_for_current_user
    if current_user.parent?
      User.all
    else
      [ current_user ]
    end
  end

  def authorize_todo_access!
    unless can_access_todo?(@todo)
      redirect_to todos_path, alert: "You don't have permission to access this todo."
    end
  end

  def authorize_todo_creation!
    # Both parents and kids can create todos, but kids can only assign to themselves
    true
  end

  def can_access_todo?(todo)
    # Parents can access all todos
    return true if current_user.parent?

    # Kids can access their own assigned todos, family-wide todos, or todos they created
    current_user == todo.assignee ||
    current_user == todo.creator ||
    todo.family_wide?
  end
end
