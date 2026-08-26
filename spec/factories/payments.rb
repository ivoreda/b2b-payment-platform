FactoryBot.define do
  factory :payment do
    order
    amount_cents { order.amount_cents }
    currency { order.currency }
    provider { "mock" }
  end
end
