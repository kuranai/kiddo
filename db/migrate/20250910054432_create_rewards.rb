class CreateRewards < ActiveRecord::Migration[8.0]
  def change
    create_table :rewards do |t|
      t.string :name, null: false
      t.text :description
      t.integer :point_cost, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :rewards, :active
    add_index :rewards, :point_cost
  end
end
