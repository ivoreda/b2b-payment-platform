FactoryBot.define do
  factory :payment_event do
    payment
    from_status { "pending" }
    to_status { "succeeded" }
    source { "webhook" }
  end
end
