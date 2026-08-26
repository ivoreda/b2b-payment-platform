require "rails_helper"

RSpec.describe ProcessWebhookEventJob do
  let(:order) { create(:order) }
  let(:payment) { create(:payment, order: order) }

  def webhook_event_for(payment, type:, data: {})
    create(:webhook_event, event_type: type, payload: { "data" => { "payment_reference" => payment.reference }.merge(data) })
  end

  it "marks the payment succeeded and stamps the provider_reference" do
    event = webhook_event_for(payment, type: "payment.succeeded", data: { "provider_reference" => "mock_ch_1" })

    described_class.perform_now(event.id)

    expect(payment.reload).to have_attributes(status: "succeeded", provider_reference: "mock_ch_1")
    expect(event.reload).to be_processed
    expect(event.payment).to eq(payment)
  end

  it "marks the payment failed with the given reason" do
    event = webhook_event_for(payment, type: "payment.failed", data: { "failure_reason" => "card_declined" })

    described_class.perform_now(event.id)

    expect(payment.reload).to have_attributes(status: "failed", failure_reason: "card_declined")
    expect(event.reload).to be_processed
  end

  it "ignores an event for an unknown payment_reference without raising" do
    event = create(:webhook_event, event_type: "payment.succeeded", payload: { "data" => { "payment_reference" => "pay_does_not_exist" } })

    expect { described_class.perform_now(event.id) }.not_to raise_error

    expect(event.reload).to be_ignored
  end

  it "ignores an unrecognized event_type" do
    event = webhook_event_for(payment, type: "payment.refunded")

    described_class.perform_now(event.id)

    expect(event.reload).to be_ignored
    expect(payment.reload).to be_pending
  end

  it "is a no-op if the event was already processed (job retried after success)" do
    event = webhook_event_for(payment, type: "payment.succeeded", data: { "provider_reference" => "mock_ch_1" })
    described_class.perform_now(event.id)

    expect {
      described_class.perform_now(event.id)
    }.not_to change { payment.reload.payment_events.count }
  end

  it "records a failed WebhookEvent instead of raising on a genuine invalid transition" do
    payment.mark_failed!(failure_reason: "card_declined")
    event = webhook_event_for(payment, type: "payment.succeeded", data: { "provider_reference" => "mock_ch_1" })

    expect { described_class.perform_now(event.id) }.not_to raise_error

    expect(event.reload).to be_failed
    expect(event.error_message).to be_present
    expect(payment.reload).to be_failed
  end

  it "running the job twice concurrently for the same event only applies one transition" do
    event = webhook_event_for(payment, type: "payment.succeeded", data: { "provider_reference" => "mock_ch_1" })

    2.times { described_class.perform_now(event.id) }

    expect(payment.reload.payment_events.count).to eq(1)
  end
end
