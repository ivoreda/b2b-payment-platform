require "rails_helper"

RSpec.describe Payment, type: :model do
  it "is valid when amount and currency match its order" do
    payment = build(:payment)

    expect(payment).to be_valid
  end

  it "assigns an opaque, prefixed reference on create" do
    payment = create(:payment)

    expect(payment.reference).to match(/\Apay_[0-9a-f]{24}\z/)
  end

  it "rejects a duplicate reference" do
    existing = create(:payment)

    duplicate = build(:payment, reference: existing.reference)

    expect(duplicate).not_to be_valid
  end

  it "copies the merchant from its order" do
    order = create(:order)
    payment = create(:payment, order: order)

    expect(payment.merchant).to eq(order.merchant)
  end

  it "rejects an amount that does not match the order's amount" do
    order = create(:order, amount_cents: 5_000)
    payment = build(:payment, order: order, amount_cents: 4_999)

    expect(payment).not_to be_valid
    expect(payment.errors[:amount_cents]).to be_present
  end

  it "rejects a currency that does not match the order's currency" do
    order = create(:order, currency: "USD")
    payment = build(:payment, order: order, currency: "EUR")

    expect(payment).not_to be_valid
    expect(payment.errors[:currency]).to be_present
  end

  it "rejects a zero amount" do
    payment = build(:payment, amount_cents: 0)

    expect(payment).not_to be_valid
  end

  it "rejects a negative amount" do
    payment = build(:payment, amount_cents: -100)

    expect(payment).not_to be_valid
  end

  it "allows two payments on different orders to reuse the same idempotency key across merchants" do
    create(:payment, idempotency_key: "shared-key")
    other = build(:payment, idempotency_key: "shared-key")

    expect(other).to be_valid
  end

  it "rejects a duplicate idempotency key within the same merchant" do
    order = create(:order)
    create(:payment, order: order, idempotency_key: "dup-key")
    duplicate = build(:payment, order: create(:order, merchant: order.merchant), idempotency_key: "dup-key")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:idempotency_key]).to be_present
  end

  it "allows multiple payments with no idempotency key" do
    order = create(:order)
    create(:payment, order: order, idempotency_key: nil)
    second = build(:payment, order: order, idempotency_key: nil)

    expect(second).to be_valid
  end

  it "enforces the positive-amount check constraint at the database level, independent of model validation" do
    payment = create(:payment)

    expect {
      payment.update_column(:amount_cents, 0) # rubocop:disable Rails/SkipsModelValidations -- proving the DB constraint holds even when AR validations are bypassed
    }.to raise_error(ActiveRecord::StatementInvalid, /payments_amount_cents_positive/)
  end

  describe ".for_merchant" do
    it "scopes to only the given merchant's payments" do
      merchant_a = create(:merchant)
      merchant_b = create(:merchant)
      payment_a = create(:payment, order: create(:order, merchant: merchant_a))
      create(:payment, order: create(:order, merchant: merchant_b))

      expect(Payment.for_merchant(merchant_a)).to contain_exactly(payment_a)
    end
  end
end
