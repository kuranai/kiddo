class CreateInternetControlStates < ActiveRecord::Migration[8.0]
  def change
    create_table :internet_control_states do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.boolean :internet_enabled, null: false, default: true
      t.boolean :controlled_by_timer, null: false, default: false
      t.references :manual_override_by, null: true, foreign_key: { to_table: :users }
      t.text :override_reason
      t.datetime :last_controlled_at

      t.timestamps
    end

    add_index :internet_control_states, :internet_enabled
    add_index :internet_control_states, :controlled_by_timer
    add_index :internet_control_states, :last_controlled_at
  end
end
