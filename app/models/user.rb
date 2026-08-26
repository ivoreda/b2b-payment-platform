class User < ApplicationRecord
  belongs_to :merchant

  has_secure_password

  enum :role, { member: 0, admin: 1 }, default: :member

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true,
                     format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
end
