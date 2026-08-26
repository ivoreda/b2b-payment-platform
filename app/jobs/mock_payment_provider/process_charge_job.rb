module MockPaymentProvider
  # The "async notification arriving" half of the simulated gateway.
  # Builds a genuinely signed payload and feeds it through the same
  # processor a real inbound webhook request would go through.
  class ProcessChargeJob < ApplicationJob
    queue_as :default

    def perform(payment_id)
      payment = Payment.find(payment_id)
      raw_body = MockPaymentProvider.event_for(payment).to_json

      Webhooks::PaymentProviderProcessor.call(
        raw_body: raw_body,
        signature_header: Webhooks::SignatureVerifier.header_for(raw_body)
      )
    end
  end
end
