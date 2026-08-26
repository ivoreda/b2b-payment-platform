class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.string :reference, null: false
      t.references :order, null: false, foreign_key: true
      t.references :merchant, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.string :currency, null: false, limit: 3
      t.integer :status, null: false, default: 0
      t.string :provider, null: false, default: "mock"
      t.string :provider_reference
      t.string :idempotency_key
      t.string :failure_reason
      t.datetime :succeeded_at
      t.datetime :failed_at

      t.timestamps
    end

    add_index :payments, :reference, unique: true
    add_index :payments, [ :merchant_id, :idempotency_key ], unique: true
    add_check_constraint :payments, "amount_cents > 0", name: "payments_amount_cents_positive"
  end
end
