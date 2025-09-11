class MakeAssigneeIdNullableInTodos < ActiveRecord::Migration[8.0]
  def change
    change_column_null :todos, :assignee_id, true
  end
end
