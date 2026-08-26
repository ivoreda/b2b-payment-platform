require "rails_helper"

RSpec.describe WebhookEvent, type: :model do
  it "is valid with provider, provider_event_id, event_type, and signature_valid" do
    event = build(:webhook_event)

    expect(event).to be_valid
  end

  it "rejects a duplicate provider_event_id for the same provider" do
    create(:webhook_event, provider: "mock", provider_event_id: "evt_dup")
    duplicate = build(:webhook_event, provider: "mock", provider_event_id: "evt_dup")

    expect(duplicate).not_to be_valid
  end

  it "allows the same provider_event_id across two different providers" do
    create(:webhook_event, provider: "mock", provider_event_id: "evt_shared")
    other = build(:webhook_event, provider: "other-provider", provider_event_id: "evt_shared")

    expect(other).to be_valid
  end

  it "enforces the duplicate rejection at the database level too" do
    create(:webhook_event, provider: "mock", provider_event_id: "evt_dup_db")

    expect {
      WebhookEvent.insert!({ provider: "mock", provider_event_id: "evt_dup_db", event_type: "x", payload: {}, signature_valid: true })
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "defaults to received status" do
    expect(WebhookEvent.new.status).to eq("received")
  end
end
