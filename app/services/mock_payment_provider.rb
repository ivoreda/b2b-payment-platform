# No real network call: .charge schedules ProcessChargeJob, which signs a payload and hands it to
# Webhooks::PaymentProviderProcessor - the same object the public webhook endpoint calls.
# Deterministic, not random: amount_cents ending in 99 (e.g. 1099) declines; everything else succeeds.
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
