class CreateTodos < ActiveRecord::Migration[8.0]
  def change
    create_table :todos do |t|
      t.string :title, null: false
      t.text :description
      t.integer :points, null: false, default: 1
      t.integer :assignee_id, null: false
      t.integer :creator_id, null: false
      t.datetime :due_date
      t.boolean :completed, null: false, default: false
      t.datetime :completed_at
      t.boolean :recurring, null: false, default: false
      t.integer :recurring_type
      t.text :recurring_days
      t.boolean :family_wide, null: false, default: false

      t.timestamps
    end

    add_index :todos, :assignee_id
    add_index :todos, :creator_id
    add_index :todos, :completed
    add_index :todos, :due_date
    add_index :todos, :family_wide
    add_foreign_key :todos, :users, column: :assignee_id
    add_foreign_key :todos, :users, column: :creator_id
  end
end
