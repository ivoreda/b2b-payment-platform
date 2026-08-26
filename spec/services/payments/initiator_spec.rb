require "rails_helper"

RSpec.describe Payments::Initiator do
  let(:merchant) { create(:merchant) }
  let(:order) { create(:order, merchant: merchant) }

  describe ".call" do
    it "creates a payment matching the order's amount/currency and moves the order to awaiting_payment" do
      result = described_class.call(order: order, idempotency_key: "key-1")

      expect(result.idempotent_replay).to be false
      expect(result.payment).to be_persisted
      expect(result.payment.amount_cents).to eq(order.amount_cents)
      expect(result.payment.currency).to eq(order.currency)
      expect(order.reload).to be_awaiting_payment
    end

    it "returns the same payment for a replayed idempotency key on the same order" do
      first = described_class.call(order: order, idempotency_key: "key-1")
      second = described_class.call(order: order, idempotency_key: "key-1")

      expect(second.idempotent_replay).to be true
      expect(second.payment).to eq(first.payment)
    end

    it "allows a retry payment while the order is still awaiting_payment" do
      described_class.call(order: order, idempotency_key: "attempt-1")

      result = described_class.call(order: order, idempotency_key: "attempt-2")

      expect(result.idempotent_replay).to be false
      expect(order.payments.count).to eq(2)
    end

    it "raises OrderNotPayable for a paid order with a new idempotency key" do
      order.update!(status: :paid)

      expect {
        described_class.call(order: order, idempotency_key: "key-2")
      }.to raise_error(Payments::Initiator::OrderNotPayable)
    end

    it "raises IdempotencyKeyConflict when the same key is reused for a different order" do
      described_class.call(order: order, idempotency_key: "shared")
      other_order = create(:order, merchant: merchant)

      expect {
        described_class.call(order: other_order, idempotency_key: "shared")
      }.to raise_error(Payments::Initiator::IdempotencyKeyConflict)
    end

    it "recovers from a same-order unique-index race by treating the winning payment as a replay" do
      racer = create(:payment, order: order, idempotency_key: "race-key")
      # Simulate two concurrent requests both missing the pre-check race window:
      # the row exists by the time we insert, but not yet when we looked it up.
      allow(order.merchant.payments).to receive(:find_by).and_return(nil)

      result = described_class.call(order: order, idempotency_key: "race-key")

      expect(result.idempotent_replay).to be true
      expect(result.payment).to eq(racer)
    end

    it "recovers from a cross-order unique-index race by raising IdempotencyKeyConflict" do
      racer_order = create(:order, merchant: merchant)
      create(:payment, order: racer_order, idempotency_key: "race-key")
      allow(order.merchant.payments).to receive(:find_by).and_return(nil)

      expect {
        described_class.call(order: order, idempotency_key: "race-key")
      }.to raise_error(Payments::Initiator::IdempotencyKeyConflict)
    end
  end
end
