class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :reference, null: false
      t.references :merchant, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.string :currency, null: false, limit: 3
      t.integer :status, null: false, default: 0
      t.string :customer_email, null: false
      t.string :customer_name

      t.timestamps
    end

    add_index :orders, :reference, unique: true
    add_check_constraint :orders, "amount_cents > 0", name: "orders_amount_cents_positive"
  end
end
