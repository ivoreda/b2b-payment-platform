FactoryBot.define do
  factory :api_credential do
    merchant
    name { "Test API Key" }
  end
end
