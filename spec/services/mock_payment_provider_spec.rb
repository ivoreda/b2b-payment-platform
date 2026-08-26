require "rails_helper"

RSpec.describe MockPaymentProvider do
  describe ".declined?" do
    it "declines an amount ending in .99" do
      payment = build(:payment, amount_cents: 1_099)

      expect(described_class.declined?(payment)).to be true
    end

    it "succeeds for any other amount" do
      payment = build(:payment, amount_cents: 1_000)

      expect(described_class.declined?(payment)).to be false
    end
  end

  describe ".event_for" do
    it "builds a payment.succeeded event for a non-declined amount" do
      order = create(:order, amount_cents: 1_000)
      payment = create(:payment, order: order)

      event = described_class.event_for(payment)

      expect(event[:type]).to eq("payment.succeeded")
      expect(event[:data][:payment_reference]).to eq(payment.reference)
      expect(event[:data][:provider_reference]).to be_present
      expect(event[:id]).to be_present
    end

    it "builds a payment.failed event for a declined amount" do
      order = create(:order, amount_cents: 1_099)
      payment = create(:payment, order: order)

      event = described_class.event_for(payment)

      expect(event[:type]).to eq("payment.failed")
      expect(event[:data][:payment_reference]).to eq(payment.reference)
      expect(event[:data][:failure_reason]).to eq("card_declined")
    end

    it "generates a fresh event id each time" do
      payment = create(:payment)

      first_id = described_class.event_for(payment)[:id]
      second_id = described_class.event_for(payment)[:id]

      expect(first_id).not_to eq(second_id)
    end
  end

  describe ".charge" do
    it "schedules ProcessChargeJob after the notification delay" do
      payment = create(:payment)

      expect {
        described_class.charge(payment)
      }.to have_enqueued_job(MockPaymentProvider::ProcessChargeJob)
        .with(payment.id)
        .at(a_value_within(1.second).of(described_class::NOTIFICATION_DELAY.from_now))
    end
  end
end
