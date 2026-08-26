FactoryBot.define do
  factory :order do
    merchant
    amount_cents { 10_000 }
    currency { "USD" }
    customer_email { Faker::Internet.email }
    customer_name { Faker::Name.name }
  end
end
