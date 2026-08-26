class Payment < ApplicationRecord
  include HasReference
  reference_prefix "pay"

  class InvalidTransition < StandardError; end

  belongs_to :order
  belongs_to :merchant
  has_many :payment_events, dependent: :destroy

  enum :status, { pending: 0, processing: 1, succeeded: 2, failed: 3 }, default: :pending

  normalizes :currency, with: ->(currency) { currency.to_s.strip.upcase }

  before_validation :copy_merchant_from_order, on: :create

  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/, message: "must be a 3-letter ISO currency code" }
  validates :idempotency_key, uniqueness: { scope: :merchant_id }, allow_nil: true
  validate :amount_and_currency_match_order

  scope :for_merchant, ->(merchant) { where(merchant: merchant) }

  # These three are the only ways a Payment's status is ever allowed to
  # change after creation. Each is idempotent-safe (a redelivered or
  # out-of-order notification for a status the payment is already at, or
  # already past, is a silent no-op) but raises on a genuine contradiction
  # (e.g. a "succeeded" notification for a payment already marked
  # "failed") rather than silently overwriting a terminal outcome - that
  # case indicates either a provider bug or a forged webhook, and both
  # deserve investigation rather than being swallowed.

  def mark_processing!(webhook_event: nil)
    with_lock do
      next :noop unless pending?

      apply_transition!(to: "processing", webhook_event: webhook_event)
    end
  end

  def mark_succeeded!(provider_reference:, webhook_event: nil)
    with_lock do
      next :noop if succeeded?
      raise InvalidTransition, "cannot mark a #{status} payment as succeeded" if failed?

      previous_status = status
      update!(status: :succeeded, provider_reference: provider_reference, succeeded_at: Time.current)
      payment_events.create!(from_status: previous_status, to_status: "succeeded", source: "webhook", webhook_event: webhook_event)
      order.with_lock { order.update!(status: :paid) }
      :transitioned
    end
  end

  def mark_failed!(failure_reason:, webhook_event: nil)
    with_lock do
      next :noop if failed?
      raise InvalidTransition, "cannot mark a #{status} payment as failed" if succeeded?

      previous_status = status
      update!(status: :failed, failure_reason: failure_reason, failed_at: Time.current)
      payment_events.create!(from_status: previous_status, to_status: "failed", source: "webhook", webhook_event: webhook_event)
      :transitioned
    end
  end

  private

  def apply_transition!(to:, webhook_event:)
    previous_status = status
    update!(status: to)
    payment_events.create!(from_status: previous_status, to_status: to, source: "webhook", webhook_event: webhook_event)
    :transitioned
  end

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
