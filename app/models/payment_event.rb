# Append-only audit trail of every Payment status change, distinct from the raw WebhookEvent log.
class PaymentEvent < ApplicationRecord
  belongs_to :payment
  belongs_to :webhook_event, optional: true

  validates :from_status, presence: true
  validates :to_status, presence: true
  validates :source, presence: true, inclusion: { in: %w[webhook api system] }
end
