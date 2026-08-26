class Order < ApplicationRecord
  include HasReference
  reference_prefix "ord"

  belongs_to :merchant
  has_many :payments, dependent: :destroy

  enum :status, { pending: 0, awaiting_payment: 1, paid: 2, cancelled: 3, failed: 4 }, default: :pending

  normalizes :currency, with: ->(currency) { currency.to_s.strip.upcase }

  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/, message: "must be a 3-letter ISO currency code" }
  validates :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :for_merchant, ->(merchant) { where(merchant: merchant) }

  # Sorts in Ruby, not SQL, so this stays N+1-safe when `payments` has
  # already been preloaded (e.g. via includes(:payments) on an index view).
  def latest_payment
    payments.max_by(&:created_at)
  end

  # So url/path helpers (dashboard_order_path(order)) build the opaque
  # reference into the URL instead of the internal sequential id.
  def to_param
    reference
  end
end
