module MockPaymentProvider
  # Signs a payload and feeds it through the same processor a real inbound webhook would hit.
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
