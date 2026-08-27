require "rails_helper"

RSpec.describe "Dashboard::ApiCredentials", type: :request do
  let(:merchant) { create(:merchant) }
  let(:admin) { create(:user, merchant: merchant, role: :admin, password: "password123") }
  let(:member) { create(:user, merchant: merchant, role: :member, password: "password123") }

  def login_as(user)
    post login_path, params: { email: user.email, password: "password123" }
  end

  describe "GET /dashboard/api_credentials" do
    it "redirects to login when logged out" do
      get dashboard_api_credentials_path

      expect(response).to redirect_to(login_path)
    end

    it "redirects a non-admin member instead of showing the page" do
      login_as(member)

      get dashboard_api_credentials_path

      expect(response).to redirect_to(dashboard_orders_path)
    end

    it "lists only the current merchant's credentials for an admin" do
      login_as(admin)
      mine = create(:api_credential, merchant: merchant, name: "Mine")
      create(:api_credential, merchant: create(:merchant), name: "Theirs")

      get dashboard_api_credentials_path

      expect(response.body).to include("Mine")
      expect(response.body).not_to include("Theirs")
    end
  end

  describe "POST /dashboard/api_credentials" do
    it "redirects a non-admin member instead of creating a credential" do
      login_as(member)

      expect {
        post dashboard_api_credentials_path, params: { api_credential: { name: "New Key" } }
      }.not_to change(ApiCredential, :count)

      expect(response).to redirect_to(dashboard_orders_path)
    end

    it "creates a credential for an admin and reveals the raw token once via flash" do
      login_as(admin)

      post dashboard_api_credentials_path, params: { api_credential: { name: "New Key" } }
      expect(response).to redirect_to(dashboard_api_credentials_path)

      follow_redirect!
      revealed_token = response.body[/sk_[0-9a-f]+/]
      expect(revealed_token).to be_present
      expect(ApiCredential.authenticate(revealed_token)).to eq(merchant.api_credentials.find_by!(name: "New Key"))
    end

    it "re-renders with errors instead of creating a nameless credential" do
      login_as(admin)

      expect {
        post dashboard_api_credentials_path, params: { api_credential: { name: "" } }
      }.not_to change(ApiCredential, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /dashboard/api_credentials/:id" do
    it "redirects a non-admin member instead of revoking" do
      login_as(member)
      credential = create(:api_credential, merchant: merchant)

      delete dashboard_api_credential_path(credential)

      expect(credential.reload).not_to be_revoked
      expect(response).to redirect_to(dashboard_orders_path)
    end

    it "revokes the credential for an admin without deleting the row" do
      login_as(admin)
      credential = create(:api_credential, merchant: merchant)

      delete dashboard_api_credential_path(credential)

      expect(credential.reload).to be_revoked
      expect(response).to redirect_to(dashboard_api_credentials_path)
    end

    it "returns 404 for another merchant's credential instead of revoking it" do
      login_as(admin)
      other_credential = create(:api_credential, merchant: create(:merchant))

      delete dashboard_api_credential_path(other_credential)

      expect(response).to have_http_status(:not_found)
      expect(other_credential.reload).not_to be_revoked
    end
  end
end
