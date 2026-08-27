# Append-only log of inbound provider notifications, deduped on (provider, provider_event_id).
class WebhookEvent < ApplicationRecord
  belongs_to :payment, optional: true
  has_many :payment_events, dependent: :nullify

  enum :status, { received: 0, processed: 1, ignored: 2, failed: 3 }, default: :received

  validates :provider, presence: true
  validates :provider_event_id, presence: true, uniqueness: { scope: :provider }
  validates :event_type, presence: true
  validates :signature_valid, inclusion: { in: [ true, false ] }
end
