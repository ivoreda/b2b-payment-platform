class CreatePaymentEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_events do |t|
      t.references :payment, null: false, foreign_key: true
      t.string :from_status, null: false
      t.string :to_status, null: false
      t.string :source, null: false
      t.references :webhook_event, null: true, foreign_key: true

      t.datetime :created_at, null: false
    end
  end
end
