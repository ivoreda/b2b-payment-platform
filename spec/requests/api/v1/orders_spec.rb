require "rails_helper"

RSpec.describe "API::V1::Orders", type: :request do
  let(:merchant) { create(:merchant) }
  let(:credential) { create(:api_credential, merchant: merchant) }
  let(:auth_headers) { { "Authorization" => "Bearer #{credential.token}" } }

  describe "POST /api/v1/orders" do
    let(:valid_params) do
      { order: { amount_cents: 5_000, currency: "usd", customer_email: "buyer@example.com", customer_name: "Buyer Co" } }
    end

    def create_order(params: valid_params, idempotency_key: "test-key-1", headers: auth_headers)
      request_headers = headers.merge("Idempotency-Key" => idempotency_key).compact
      post "/api/v1/orders", params: params, headers: request_headers, as: :json
    end

    it "creates an order for the authenticated merchant" do
      create_order

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["amount_cents"]).to eq(5_000)
      expect(body["currency"]).to eq("USD")
      expect(body["status"]).to eq("pending")
      expect(merchant.orders.find_by!(reference: body["reference"])).to be_present
    end

    it "rejects requests without a token" do
      create_order(headers: {})

      expect(response).to have_http_status(:unauthorized)
      expect(Order.count).to eq(0)
    end

    it "rejects requests with an invalid token" do
      create_order(headers: { "Authorization" => "Bearer sk_bogus" })

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects requests with a revoked token" do
      credential.revoke!

      create_order

      expect(response).to have_http_status(:unauthorized)
    end

    it "requires an Idempotency-Key header" do
      create_order(idempotency_key: nil)

      expect(response).to have_http_status(:bad_request)
      expect(Order.count).to eq(0)
    end

    it "returns the existing order instead of creating a duplicate on key replay" do
      create_order(idempotency_key: "same-key")
      first_reference = response.parsed_body["reference"]

      expect {
        create_order(idempotency_key: "same-key")
      }.not_to change(Order, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["reference"]).to eq(first_reference)
    end

    it "ignores an injected status param instead of honoring it" do
      params = valid_params.deep_merge(order: { status: "paid" })

      create_order(params: params)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["status"]).to eq("pending")
    end

    it "rejects a non-positive amount" do
      params = valid_params.deep_merge(order: { amount_cents: 0 })

      create_order(params: params)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("Validation failed")
      expect(response.parsed_body["details"]).to be_present
    end

    it "rejects a request with no order param with 400 instead of 500" do
      post "/api/v1/orders", params: {}, headers: auth_headers.merge("Idempotency-Key" => "test-key-1"), as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET /api/v1/orders/:reference" do
    it "returns the order when it belongs to the authenticated merchant" do
      order = create(:order, merchant: merchant)

      get "/api/v1/orders/#{order.reference}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["reference"]).to eq(order.reference)
    end

    it "returns 404 for another merchant's order" do
      other_order = create(:order, merchant: create(:merchant))

      get "/api/v1/orders/#{other_order.reference}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for an unknown reference" do
      get "/api/v1/orders/ord_does_not_exist", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/orders" do
    it "returns only the authenticated merchant's orders" do
      mine = create_list(:order, 2, merchant: merchant)
      create(:order, merchant: create(:merchant))

      get "/api/v1/orders", headers: auth_headers

      references = response.parsed_body["orders"].map { |o| o["reference"] }
      expect(references).to match_array(mine.map(&:reference))
    end

    it "caps per_page at the maximum" do
      create_list(:order, 3, merchant: merchant)

      get "/api/v1/orders", params: { per_page: 1_000 }, headers: auth_headers

      expect(response.parsed_body["meta"]["per_page"]).to eq(Api::V1::OrdersController::MAX_PER_PAGE)
    end

    it "defaults per_page when given a non-positive value" do
      get "/api/v1/orders", params: { per_page: -5 }, headers: auth_headers

      expect(response.parsed_body["meta"]["per_page"]).to eq(Api::V1::OrdersController::DEFAULT_PER_PAGE)
    end
  end
end
