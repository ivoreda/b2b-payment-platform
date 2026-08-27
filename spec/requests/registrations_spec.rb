require "rails_helper"

RSpec.describe "Registrations", type: :request do
  let(:valid_params) do
    { merchant: { name: "New Merchant Co" },
      user: { email: "founder@example.com", password: "password123", password_confirmation: "password123" } }
  end

  describe "GET /signup" do
    it "renders the form" do
      get signup_path

      expect(response).to have_http_status(:ok)
    end

    it "redirects an already-logged-in user to the dashboard" do
      merchant = create(:merchant)
      user = create(:user, merchant: merchant, password: "password123")
      post login_path, params: { email: user.email, password: "password123" }

      get signup_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /signup" do
    it "creates a merchant, an admin user, and an API credential, then logs the user in" do
      expect {
        post signup_path, params: valid_params
      }.to change(Merchant, :count).by(1).and change(User, :count).by(1).and change(ApiCredential, :count).by(1)

      merchant = Merchant.find_by!(name: "New Merchant Co")
      user = merchant.users.sole
      expect(user.email).to eq("founder@example.com")
      expect(user).to be_admin
      expect(merchant).to be_active

      expect(response).to redirect_to(dashboard_api_credentials_path)
      follow_redirect!
      expect(response.body).to include("Welcome!")
      expect(response.body[/sk_[0-9a-f]+/]).to be_present
    end

    it "does not create anything if the password is too short" do
      params = valid_params.deep_merge(user: { password: "short", password_confirmation: "short" })

      expect {
        post signup_path, params: params
      }.not_to change(Merchant, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(User.count).to eq(0)
    end

    it "does not create anything if the password confirmation does not match" do
      params = valid_params.deep_merge(user: { password_confirmation: "does-not-match" })

      expect {
        post signup_path, params: params
      }.not_to change(Merchant, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create a merchant when the email is already taken" do
      create(:user, email: "founder@example.com")

      expect {
        post signup_path, params: valid_params
      }.not_to change(Merchant, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not create anything when the company name is blank" do
      params = valid_params.deep_merge(merchant: { name: "" })

      expect {
        post signup_path, params: params
      }.not_to change(Merchant, :count)
      expect(User.count).to eq(0)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "ignores an injected role param instead of granting it" do
      params = valid_params.deep_merge(user: { role: "member" })

      post signup_path, params: params

      expect(Merchant.find_by!(name: "New Merchant Co").users.sole).to be_admin
    end
  end
end
