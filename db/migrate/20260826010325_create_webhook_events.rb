class CreateWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_events do |t|
      t.string :provider, null: false
      t.string :provider_event_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.boolean :signature_valid, null: false
      t.references :payment, null: true, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :error_message

      t.timestamps
    end

    add_index :webhook_events, [ :provider, :provider_event_id ], unique: true
  end
end
