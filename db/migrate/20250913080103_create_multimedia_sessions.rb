class CreateMultimediaSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :multimedia_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :duration_minutes, default: 0
      t.integer :session_type, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :multimedia_sessions, :started_at
    add_index :multimedia_sessions, :active
    add_index :multimedia_sessions, [:user_id, :active]
    add_index :multimedia_sessions, [:user_id, :started_at]
    add_index :multimedia_sessions, :session_type
  end
end
