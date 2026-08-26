# Append-only audit trail of every status change a Payment goes through,
# regardless of source (webhook today; API/system in principle later). This
# is what a dashboard's "payment history" view would read from - distinct
# from WebhookEvent, which logs the raw inbound notifications themselves.
class PaymentEvent < ApplicationRecord
  belongs_to :payment
  belongs_to :webhook_event, optional: true

  validates :from_status, presence: true
  validates :to_status, presence: true
  validates :source, presence: true, inclusion: { in: %w[webhook api system] }
end
