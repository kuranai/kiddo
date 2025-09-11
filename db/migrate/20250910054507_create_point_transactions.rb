class CreatePointTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :point_transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount, null: false
      t.string :description, null: false
      t.references :todo, null: true, foreign_key: true
      t.references :reward, null: true, foreign_key: true
      t.integer :transaction_type, null: false

      t.timestamps
    end

    add_index :point_transactions, :transaction_type
    add_index :point_transactions, :created_at
    add_index :point_transactions, [ :user_id, :created_at ]
  end
end
