# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# `bin/rails db:prepare` automatically runs db:seed the first time it loads a
# database's schema from scratch - which includes the test database, freshly
# created on every CI run. RSpec's request specs rely on the test database
# starting genuinely empty (they assert on absolute counts, e.g. "no payment
# was created"), so demo data must never land there.
if Rails.env.test?
  puts "Skipping db/seeds.rb: demo data is never loaded into the test database."
  return
end

merchant = Merchant.find_or_create_by!(name: "Acme Test Merchant")

user = User.find_or_initialize_by(email: "demo@example.com")
user.merchant = merchant
user.password = "password123"
user.role = :admin
user.save!

credential = merchant.api_credentials.find_by(name: "Seed Demo Key")
if credential
  puts "API credential 'Seed Demo Key' already exists - its token was only ever shown once, at creation."
else
  credential = merchant.api_credentials.create!(name: "Seed Demo Key")
  puts "\nAPI credential created - copy this bearer token now, it will not be shown again:\n\n  #{credential.token}\n\n"
end

# A pending order with no payment yet. Use this one to try the dashboard's
# "Initiate Payment" button, or POST /api/v1/orders/:reference/payments, and
# watch the real (2-second-delayed) mock provider webhook pipeline run.
Order.find_or_create_by!(merchant: merchant, customer_email: "pending@example.com") do |order|
  order.amount_cents = 5_000
  order.currency = "USD"
  order.customer_name = "Pending Customer"
end

# A pre-completed successful order and a pre-declined order, set up directly
# rather than through the async pipeline, so the dashboard has something to
# show immediately without waiting on a background job.
paid_order = Order.find_or_create_by!(merchant: merchant, customer_email: "paid@example.com") do |order|
  order.amount_cents = 12_000
  order.currency = "USD"
  order.customer_name = "Paid Customer"
end
if paid_order.payments.none?
  payment = paid_order.payments.create!(merchant: merchant, amount_cents: paid_order.amount_cents, currency: paid_order.currency)
  payment.mark_succeeded!(provider_reference: "seed_demo_charge_1")
end

declined_order = Order.find_or_create_by!(merchant: merchant, customer_email: "declined@example.com") do |order|
  # Ends in .99 - MockPaymentProvider's deterministic decline rule (see app/services/mock_payment_provider.rb).
  order.amount_cents = 1_099
  order.currency = "USD"
  order.customer_name = "Declined Customer"
  order.status = :awaiting_payment
end
if declined_order.payments.none?
  payment = declined_order.payments.create!(merchant: merchant, amount_cents: declined_order.amount_cents, currency: declined_order.currency)
  payment.mark_failed!(failure_reason: "card_declined")
end

puts "Seeded merchant '#{merchant.name}'. Dashboard login: demo@example.com / password123"
