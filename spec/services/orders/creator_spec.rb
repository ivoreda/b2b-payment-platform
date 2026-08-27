require "rails_helper"

RSpec.describe Orders::Creator do
  let(:merchant) { create(:merchant) }
  let(:order_params) { { amount_cents: 5_000, currency: "USD", customer_email: "buyer@example.com", customer_name: "Buyer Co" } }

  describe ".call" do
    it "creates an order for the merchant" do
      result = described_class.call(merchant: merchant, idempotency_key: "key-1", order_params: order_params)

      expect(result.idempotent_replay).to be false
      expect(result.order).to be_persisted
      expect(result.order.merchant).to eq(merchant)
      expect(result.order.amount_cents).to eq(5_000)
    end

    it "returns the same order for a replayed idempotency key" do
      first = described_class.call(merchant: merchant, idempotency_key: "key-1", order_params: order_params)
      second = described_class.call(merchant: merchant, idempotency_key: "key-1", order_params: order_params)

      expect(second.idempotent_replay).to be true
      expect(second.order).to eq(first.order)
    end

    it "does not create a duplicate order on key replay" do
      described_class.call(merchant: merchant, idempotency_key: "key-1", order_params: order_params)

      expect {
        described_class.call(merchant: merchant, idempotency_key: "key-1", order_params: order_params)
      }.not_to change(Order, :count)
    end

    it "allows the same merchant to use a different key for a genuinely new order" do
      described_class.call(merchant: merchant, idempotency_key: "key-1", order_params: order_params)

      result = described_class.call(merchant: merchant, idempotency_key: "key-2", order_params: order_params)

      expect(result.idempotent_replay).to be false
      expect(merchant.orders.count).to eq(2)
    end

    it "raises RecordInvalid for an invalid order instead of creating it" do
      expect {
        described_class.call(merchant: merchant, idempotency_key: "key-1", order_params: order_params.merge(amount_cents: 0))
      }.to raise_error(ActiveRecord::RecordInvalid)

      expect(Order.count).to eq(0)
    end

    it "recovers from a unique-index race by treating the winning order as a replay" do
      racer = create(:order, merchant: merchant, idempotency_key: "race-key")
      # Simulate two concurrent requests both missing the pre-check race window:
      # the row exists by the time we insert, but not yet when we looked it up.
      allow(merchant.orders).to receive(:find_by).and_return(nil)

      result = described_class.call(merchant: merchant, idempotency_key: "race-key", order_params: order_params)

      expect(result.idempotent_replay).to be true
      expect(result.order).to eq(racer)
    end
  end
end
