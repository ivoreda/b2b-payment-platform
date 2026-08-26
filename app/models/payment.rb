class Payment < ApplicationRecord
  include HasReference
  reference_prefix "pay"

  belongs_to :order
  belongs_to :merchant

  enum :status, { pending: 0, processing: 1, succeeded: 2, failed: 3 }, default: :pending

  normalizes :currency, with: ->(currency) { currency.to_s.strip.upcase }

  before_validation :copy_merchant_from_order, on: :create

  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/, message: "must be a 3-letter ISO currency code" }
  validates :idempotency_key, uniqueness: { scope: :merchant_id }, allow_nil: true
  validate :amount_and_currency_match_order

  scope :for_merchant, ->(merchant) { where(merchant: merchant) }

  private

  def copy_merchant_from_order
    self.merchant ||= order&.merchant
  end

  def amount_and_currency_match_order
    return unless order

    if amount_cents.present? && amount_cents != order.amount_cents
      errors.add(:amount_cents, "must match the order amount")
    end

    if currency.present? && currency != order.currency
      errors.add(:currency, "must match the order currency")
    end
  end
end
