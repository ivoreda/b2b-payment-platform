require "rails_helper"

RSpec.describe Webhooks::SignatureVerifier do
  let(:payload) { '{"id":"evt_1","type":"payment.succeeded"}' }

  describe ".valid?" do
    it "accepts a correctly signed, fresh header" do
      header = described_class.header_for(payload)

      expect(described_class.valid?(payload: payload, signature_header: header)).to be true
    end

    it "rejects a header signed with the wrong payload" do
      header = described_class.header_for('{"id":"evt_1","type":"payment.failed"}')

      expect(described_class.valid?(payload: payload, signature_header: header)).to be false
    end

    it "rejects a tampered signature" do
      timestamp = Time.now.to_i
      header = "t=#{timestamp},v1=#{'0' * 64}"

      expect(described_class.valid?(payload: payload, signature_header: header)).to be false
    end

    it "rejects a stale timestamp outside the tolerance window" do
      old_timestamp = 10.minutes.ago.to_i
      header = described_class.header_for(payload, timestamp: old_timestamp)

      expect(described_class.valid?(payload: payload, signature_header: header)).to be false
    end

    it "rejects a missing header" do
      expect(described_class.valid?(payload: payload, signature_header: nil)).to be false
    end

    it "rejects a malformed header" do
      expect(described_class.valid?(payload: payload, signature_header: "not-a-valid-header")).to be false
    end
  end
end
