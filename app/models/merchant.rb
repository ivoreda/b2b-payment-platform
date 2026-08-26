class Merchant < ApplicationRecord
  enum :status, { active: 0, suspended: 1 }, default: :active

  has_many :users, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :payments, dependent: :destroy

  validates :name, presence: true
end
