require "rails_helper"

RSpec.describe MockPaymentProvider::ProcessChargeJob do
  include ActiveJob::TestHelper

  it "marks the payment succeeded via a genuinely signed webhook round trip" do
    order = create(:order, amount_cents: 1_000)
    payment = create(:payment, order: order)

    perform_enqueued_jobs { described_class.perform_now(payment.id) }

    expect(payment.reload).to be_succeeded
    expect(payment.provider_reference).to be_present
    expect(WebhookEvent.sole).to be_processed
  end

  it "marks the payment failed for a declined amount" do
    order = create(:order, amount_cents: 1_099)
    payment = create(:payment, order: order)

    perform_enqueued_jobs { described_class.perform_now(payment.id) }

    expect(payment.reload).to be_failed
    expect(payment.failure_reason).to eq("card_declined")
  end

  it "signs the payload with the real shared secret, not a bypass" do
    payment = create(:payment)

    allow(Webhooks::SignatureVerifier).to receive(:valid?).and_call_original

    perform_enqueued_jobs { described_class.perform_now(payment.id) }

    expect(Webhooks::SignatureVerifier).to have_received(:valid?).with(hash_including(payload: kind_of(String)))
  end
end
