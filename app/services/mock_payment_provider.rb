# Stands in for a real external payment gateway. There's no real network
# call anywhere in here: .charge just schedules ProcessChargeJob to run
# after a short delay, and that job builds a signed webhook payload and
# hands it to Webhooks::PaymentProviderProcessor - the exact same object
# our public webhook endpoint calls. That means the "simulated" async
# notification still exercises a genuine verify -> dedupe -> lock ->
# transition path; only the network hop itself is faked. Swapping in a
# real gateway later means replacing this file and nothing else.
#
# The outcome is deterministic (not random) so both paths are triggerable
# on demand: an amount ending in .99 (e.g. $10.99, amount_cents: 1099)
# simulates a decline; everything else succeeds.
module MockPaymentProvider
  DECLINE_CENTS_REMAINDER = 99
  NOTIFICATION_DELAY = 2.seconds

  def self.charge(payment)
    ProcessChargeJob.set(wait: NOTIFICATION_DELAY).perform_later(payment.id)
  end

  def self.declined?(payment)
    payment.amount_cents % 100 == DECLINE_CENTS_REMAINDER
  end

  def self.event_for(payment)
    if declined?(payment)
      {
        id: "evt_#{SecureRandom.hex(12)}",
        type: "payment.failed",
        data: { payment_reference: payment.reference, failure_reason: "card_declined" }
      }
    else
      {
        id: "evt_#{SecureRandom.hex(12)}",
        type: "payment.succeeded",
        data: { payment_reference: payment.reference, provider_reference: "mock_ch_#{SecureRandom.hex(12)}" }
      }
    end
  end
end
