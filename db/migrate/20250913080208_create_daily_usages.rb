class CreateDailyUsages < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_usages do |t|
      t.references :user, null: false, foreign_key: true
      t.date :usage_date, null: false
      t.integer :total_minutes_used, null: false, default: 0
      t.integer :total_minutes_allowed, null: false, default: 60
      t.integer :bonus_minutes_earned, null: false, default: 0
      t.integer :bonus_minutes_used, null: false, default: 0
      t.integer :remaining_minutes, null: false, default: 60
      t.datetime :last_session_ended_at

      t.timestamps
    end

    add_index :daily_usages, [:user_id, :usage_date], unique: true
    add_index :daily_usages, :usage_date
    add_index :daily_usages, :remaining_minutes
  end
end
