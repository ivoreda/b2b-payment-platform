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

ActiveRecord::Schema[8.1].define(version: 2026_08_26_002633) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "merchants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "orders", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, null: false
    t.string "customer_email", null: false
    t.string "customer_name"
    t.bigint "merchant_id", null: false
    t.string "reference", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["merchant_id"], name: "index_orders_on_merchant_id"
    t.index ["reference"], name: "index_orders_on_reference", unique: true
    t.check_constraint "amount_cents > 0", name: "orders_amount_cents_positive"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, null: false
    t.datetime "failed_at"
    t.string "failure_reason"
    t.string "idempotency_key"
    t.bigint "merchant_id", null: false
    t.bigint "order_id", null: false
    t.string "provider", default: "mock", null: false
    t.string "provider_reference"
    t.string "reference", null: false
    t.integer "status", default: 0, null: false
    t.datetime "succeeded_at"
    t.datetime "updated_at", null: false
    t.index ["merchant_id", "idempotency_key"], name: "index_payments_on_merchant_id_and_idempotency_key", unique: true
    t.index ["merchant_id"], name: "index_payments_on_merchant_id"
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["reference"], name: "index_payments_on_reference", unique: true
    t.check_constraint "amount_cents > 0", name: "payments_amount_cents_positive"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.bigint "merchant_id", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["merchant_id"], name: "index_users_on_merchant_id"
  end

  add_foreign_key "orders", "merchants"
  add_foreign_key "payments", "merchants"
  add_foreign_key "payments", "orders"
  add_foreign_key "users", "merchants"
end
