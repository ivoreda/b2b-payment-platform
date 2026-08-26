require "rails_helper"

RSpec.describe PaymentEvent, type: :model do
  it "is valid with a payment, from/to status, and source" do
    event = build(:payment_event)

    expect(event).to be_valid
  end

  it "requires a recognized source" do
    event = build(:payment_event, source: "carrier_pigeon")

    expect(event).not_to be_valid
  end

  it "does not require a webhook_event" do
    event = build(:payment_event, webhook_event: nil)

    expect(event).to be_valid
  end
end
