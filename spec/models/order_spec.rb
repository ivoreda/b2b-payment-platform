require "rails_helper"

RSpec.describe Order, type: :model do
  it "is valid with a merchant, amount, currency, and customer email" do
    order = build(:order)

    expect(order).to be_valid
  end

  it "assigns an opaque, prefixed reference on create" do
    order = create(:order)

    expect(order.reference).to match(/\Aord_[0-9a-f]{24}\z/)
  end

  it "does not overwrite an explicitly assigned reference" do
    order = create(:order, reference: "ord_custom")

    expect(order.reference).to eq("ord_custom")
  end

  it "rejects a duplicate reference" do
    existing = create(:order)

    duplicate = build(:order, reference: existing.reference)

    expect(duplicate).not_to be_valid
  end

  it "rejects a zero amount" do
    order = build(:order, amount_cents: 0)

    expect(order).not_to be_valid
  end

  it "rejects a negative amount" do
    order = build(:order, amount_cents: -100)

    expect(order).not_to be_valid
  end

  it "rejects a non-integer amount" do
    order = build(:order, amount_cents: 100.5)

    expect(order).not_to be_valid
  end

  it "rejects a malformed currency code" do
    order = build(:order, currency: "US")

    expect(order).not_to be_valid
  end

  it "normalizes currency to uppercase" do
    order = create(:order, currency: "usd")

    expect(order.currency).to eq("USD")
  end

  it "requires a well-formed customer email" do
    order = build(:order, customer_email: "not-an-email")

    expect(order).not_to be_valid
  end

  it "enforces the positive-amount check constraint at the database level, independent of model validation" do
    order = create(:order)

    expect {
      order.update_column(:amount_cents, 0) # rubocop:disable Rails/SkipsModelValidations -- proving the DB constraint holds even when AR validations are bypassed
    }.to raise_error(ActiveRecord::StatementInvalid, /orders_amount_cents_positive/)
  end

  describe ".for_merchant" do
    it "scopes to only the given merchant's orders" do
      merchant_a = create(:merchant)
      merchant_b = create(:merchant)
      order_a = create(:order, merchant: merchant_a)
      create(:order, merchant: merchant_b)

      expect(Order.for_merchant(merchant_a)).to contain_exactly(order_a)
    end
  end
end
