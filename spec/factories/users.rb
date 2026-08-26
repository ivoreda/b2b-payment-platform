FactoryBot.define do
  factory :user do
    merchant
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    role { :member }
  end
end
