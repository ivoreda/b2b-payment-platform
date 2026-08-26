require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user, password: "password123") }

  describe "GET /login" do
    it "renders the login form" do
      get login_path

      expect(response).to have_http_status(:ok)
    end

    it "redirects to root if already logged in" do
      post login_path, params: { email: user.email, password: "password123" }

      get login_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /login" do
    it "logs in with valid credentials and redirects to root" do
      post login_path, params: { email: user.email, password: "password123" }

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include(user.email)
    end

    it "is case-insensitive on email" do
      post login_path, params: { email: user.email.upcase, password: "password123" }

      expect(response).to redirect_to(root_path)
    end

    it "rejects an invalid password" do
      post login_path, params: { email: user.email, password: "wrong-password" }

      expect(response).to have_http_status(:unprocessable_content)
      get root_path
      expect(response).to redirect_to(login_path)
    end

    it "rejects an unknown email" do
      post login_path, params: { email: "nobody@example.com", password: "password123" }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /logout" do
    it "logs out and redirects to login" do
      post login_path, params: { email: user.email, password: "password123" }

      delete logout_path

      expect(response).to redirect_to(login_path)
      get root_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "GET /" do
    it "redirects to login when logged out" do
      get root_path

      expect(response).to redirect_to(login_path)
    end
  end
end
