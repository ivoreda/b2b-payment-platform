FactoryBot.define do
  factory :merchant do
    sequence(:name) { |n| "#{Faker::Company.name} #{n}" }
    status { :active }
  end
end
