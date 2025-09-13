class CreateMultimediaAllowances < ActiveRecord::Migration[8.0]
  def change
    create_table :multimedia_allowances do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :monday_minutes, null: false, default: 60
      t.integer :tuesday_minutes, null: false, default: 60
      t.integer :wednesday_minutes, null: false, default: 60
      t.integer :thursday_minutes, null: false, default: 60
      t.integer :friday_minutes, null: false, default: 60
      t.integer :saturday_minutes, null: false, default: 120
      t.integer :sunday_minutes, null: false, default: 120
      t.boolean :bonus_time_enabled, null: false, default: true
      t.integer :max_bonus_minutes, null: false, default: 60

      t.timestamps
    end

  end
end
