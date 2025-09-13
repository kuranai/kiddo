# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_13_080332) do
  create_table "daily_usages", force: :cascade do |t|
    t.integer "user_id", null: false
    t.date "usage_date", null: false
    t.integer "total_minutes_used", default: 0, null: false
    t.integer "total_minutes_allowed", default: 60, null: false
    t.integer "bonus_minutes_earned", default: 0, null: false
    t.integer "bonus_minutes_used", default: 0, null: false
    t.integer "remaining_minutes", default: 60, null: false
    t.datetime "last_session_ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["remaining_minutes"], name: "index_daily_usages_on_remaining_minutes"
    t.index ["usage_date"], name: "index_daily_usages_on_usage_date"
    t.index ["user_id", "usage_date"], name: "index_daily_usages_on_user_id_and_usage_date", unique: true
    t.index ["user_id"], name: "index_daily_usages_on_user_id"
  end

  create_table "internet_control_states", force: :cascade do |t|
    t.integer "user_id", null: false
    t.boolean "internet_enabled", default: true, null: false
    t.boolean "controlled_by_timer", default: false, null: false
    t.integer "manual_override_by_id"
    t.text "override_reason"
    t.datetime "last_controlled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["controlled_by_timer"], name: "index_internet_control_states_on_controlled_by_timer"
    t.index ["internet_enabled"], name: "index_internet_control_states_on_internet_enabled"
    t.index ["last_controlled_at"], name: "index_internet_control_states_on_last_controlled_at"
    t.index ["manual_override_by_id"], name: "index_internet_control_states_on_manual_override_by_id"
    t.index ["user_id"], name: "index_internet_control_states_on_user_id", unique: true
  end

  create_table "multimedia_allowances", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "monday_minutes", default: 60, null: false
    t.integer "tuesday_minutes", default: 60, null: false
    t.integer "wednesday_minutes", default: 60, null: false
    t.integer "thursday_minutes", default: 60, null: false
    t.integer "friday_minutes", default: 60, null: false
    t.integer "saturday_minutes", default: 120, null: false
    t.integer "sunday_minutes", default: 120, null: false
    t.boolean "bonus_time_enabled", default: true, null: false
    t.integer "max_bonus_minutes", default: 60, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_multimedia_allowances_on_user_id"
  end

  create_table "multimedia_sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.integer "duration_minutes", default: 0
    t.integer "session_type", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_multimedia_sessions_on_active"
    t.index ["session_type"], name: "index_multimedia_sessions_on_session_type"
    t.index ["started_at"], name: "index_multimedia_sessions_on_started_at"
    t.index ["user_id", "active"], name: "index_multimedia_sessions_on_user_id_and_active"
    t.index ["user_id", "started_at"], name: "index_multimedia_sessions_on_user_id_and_started_at"
    t.index ["user_id"], name: "index_multimedia_sessions_on_user_id"
  end

  create_table "point_transactions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "amount", null: false
    t.string "description", null: false
    t.integer "todo_id"
    t.integer "reward_id"
    t.integer "transaction_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_point_transactions_on_created_at"
    t.index ["reward_id"], name: "index_point_transactions_on_reward_id"
    t.index ["todo_id"], name: "index_point_transactions_on_todo_id"
    t.index ["transaction_type"], name: "index_point_transactions_on_transaction_type"
    t.index ["user_id", "created_at"], name: "index_point_transactions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_point_transactions_on_user_id"
  end

  create_table "rewards", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "point_cost", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_rewards_on_active"
    t.index ["point_cost"], name: "index_rewards_on_point_cost"
  end

  create_table "todos", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.integer "points", default: 1, null: false
    t.integer "assignee_id"
    t.integer "creator_id", null: false
    t.datetime "due_date"
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
    t.boolean "recurring", default: false, null: false
    t.integer "recurring_type"
    t.text "recurring_days"
    t.boolean "family_wide", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_todos_on_assignee_id"
    t.index ["completed"], name: "index_todos_on_completed"
    t.index ["creator_id"], name: "index_todos_on_creator_id"
    t.index ["due_date"], name: "index_todos_on_due_date"
    t.index ["family_wide"], name: "index_todos_on_family_wide"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.integer "points_balance", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "daily_usages", "users"
  add_foreign_key "internet_control_states", "users"
  add_foreign_key "internet_control_states", "users", column: "manual_override_by_id"
  add_foreign_key "multimedia_allowances", "users"
  add_foreign_key "multimedia_sessions", "users"
  add_foreign_key "point_transactions", "rewards"
  add_foreign_key "point_transactions", "todos"
  add_foreign_key "point_transactions", "users"
  add_foreign_key "todos", "users", column: "assignee_id"
  add_foreign_key "todos", "users", column: "creator_id"
end
