require "rails_helper"

RSpec.describe ApiCredential, type: :model do
  it "generates a raw token, digest, and last-four on create" do
    credential = create(:api_credential)

    expect(credential.token).to match(/\Ask_[0-9a-f]{48}\z/)
    expect(credential.token_digest).to eq(Digest::SHA256.hexdigest(credential.token))
    expect(credential.token_last_four).to eq(credential.token.last(4))
  end

  it "does not expose the raw token after reloading" do
    credential = create(:api_credential)

    reloaded = ApiCredential.find(credential.id)

    expect(reloaded.token).to be_nil
  end

  it "rejects a duplicate token digest" do
    existing = create(:api_credential)

    duplicate = build(:api_credential, token_digest: existing.token_digest)

    expect(duplicate).not_to be_valid
  end

  describe ".authenticate" do
    it "returns the credential for a valid, active token" do
      credential = create(:api_credential)

      expect(ApiCredential.authenticate(credential.token)).to eq(credential)
    end

    it "returns nil for an unknown token" do
      expect(ApiCredential.authenticate("sk_does_not_exist")).to be_nil
    end

    it "returns nil for a blank token" do
      expect(ApiCredential.authenticate(nil)).to be_nil
      expect(ApiCredential.authenticate("")).to be_nil
    end

    it "returns nil for a revoked token" do
      credential = create(:api_credential)
      credential.revoke!

      expect(ApiCredential.authenticate(credential.token)).to be_nil
    end

    it "updates last_used_at on successful authentication" do
      credential = create(:api_credential)

      expect { ApiCredential.authenticate(credential.token) }
        .to change { credential.reload.last_used_at }.from(nil)
    end
  end

  describe "#revoke!" do
    it "marks the credential as revoked" do
      credential = create(:api_credential)

      expect { credential.revoke! }.to change(credential, :revoked?).from(false).to(true)
    end
  end
end
