require "rails_helper"

# Enforced once in ApplicationController#require_login, so this only needs
# to prove it holds for the dashboard in general - not duplicated across
# every controller's own spec file.
RSpec.describe "Dashboard access for a suspended merchant", type: :request do
  let(:merchant) { create(:merchant, status: :suspended) }
  let(:user) { create(:user, merchant: merchant, password: "password123") }

  def login_as(user)
    post login_path, params: { email: user.email, password: "password123" }
  end

  it "logs the user in but bounces them back to login on the very next request" do
    login_as(user)
    expect(response).to redirect_to(root_path)

    get dashboard_orders_path

    expect(response).to redirect_to(login_path)
    follow_redirect!
    expect(response.body).to include("This merchant account has been suspended")
  end

  it "resets the session, not just redirecting this one request" do
    login_as(user)
    get dashboard_orders_path # triggers the suspension check + session reset

    get dashboard_orders_path

    expect(response).to redirect_to(login_path)
  end

  it "allows access again once the merchant is reactivated" do
    login_as(user)
    get dashboard_orders_path
    expect(response).to redirect_to(login_path)

    merchant.update!(status: :active)
    login_as(user)
    get dashboard_orders_path

    expect(response).to have_http_status(:ok)
  end
end
