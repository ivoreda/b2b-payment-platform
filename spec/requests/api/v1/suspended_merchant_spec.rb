require "rails_helper"

# Enforced once in Api::V1::BaseController#authenticate_merchant!, so this
# only needs to prove it holds for the API in general - not duplicated
# across every controller's own spec file.
RSpec.describe "API access for a suspended merchant", type: :request do
  let(:merchant) { create(:merchant, status: :suspended) }
  let(:credential) { create(:api_credential, merchant: merchant) }
  let(:auth_headers) { { "Authorization" => "Bearer #{credential.token}" } }

  it "rejects an otherwise-valid token with 403, distinct from an invalid token's 401" do
    get "/api/v1/orders", headers: auth_headers

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body["error"]).to eq("Merchant account is suspended")
  end

  it "rejects order creation" do
    post "/api/v1/orders",
         params: { order: { amount_cents: 5_000, currency: "usd", customer_email: "buyer@example.com" } },
         headers: auth_headers.merge("Idempotency-Key" => "key-1"), as: :json

    expect(response).to have_http_status(:forbidden)
    expect(Order.count).to eq(0)
  end

  it "allows requests again once the merchant is reactivated" do
    get "/api/v1/orders", headers: auth_headers
    expect(response).to have_http_status(:forbidden)

    merchant.update!(status: :active)
    get "/api/v1/orders", headers: auth_headers

    expect(response).to have_http_status(:ok)
  end
end
