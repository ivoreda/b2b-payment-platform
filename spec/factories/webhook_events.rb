FactoryBot.define do
  factory :webhook_event do
    provider { "mock" }
    sequence(:provider_event_id) { |n| "evt_#{n}" }
    event_type { "payment.succeeded" }
    payload { {} }
    signature_valid { true }
    status { :received }
  end
end
