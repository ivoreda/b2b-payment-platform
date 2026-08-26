require "rails_helper"

RSpec.describe "API::V1::Payments", type: :request do
  let(:merchant) { create(:merchant) }
  let(:credential) { create(:api_credential, merchant: merchant) }
  let(:auth_headers) { { "Authorization" => "Bearer #{credential.token}" } }
  let(:order) { create(:order, merchant: merchant) }

  def initiate(order_reference, idempotency_key: "test-key-1", headers: auth_headers)
    request_headers = headers.merge("Idempotency-Key" => idempotency_key).compact
    post "/api/v1/orders/#{order_reference}/payments", headers: request_headers, as: :json
  end

  describe "POST /api/v1/orders/:order_reference/payments" do
    it "creates a pending payment and moves the order to awaiting_payment" do
      initiate(order.reference)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["status"]).to eq("pending")
      expect(body["amount_cents"]).to eq(order.amount_cents)
      expect(body["currency"]).to eq(order.currency)
      expect(order.reload.status).to eq("awaiting_payment")
    end

    it "requires an Idempotency-Key header" do
      initiate(order.reference, idempotency_key: nil)

      expect(response).to have_http_status(:bad_request)
      expect(Payment.count).to eq(0)
    end

    it "returns the existing payment instead of creating a duplicate on key replay" do
      initiate(order.reference, idempotency_key: "same-key")
      first_reference = response.parsed_body["reference"]

      expect {
        initiate(order.reference, idempotency_key: "same-key")
      }.not_to change(Payment, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["reference"]).to eq(first_reference)
    end

    it "allows a second payment attempt (retry) while the order is awaiting_payment" do
      initiate(order.reference, idempotency_key: "attempt-1")

      expect {
        initiate(order.reference, idempotency_key: "attempt-2")
      }.to change(Payment, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "rejects initiating a payment on an order that is already paid" do
      order.update!(status: :paid)

      initiate(order.reference, idempotency_key: "new-key")

      expect(response).to have_http_status(:unprocessable_content)
      expect(Payment.count).to eq(0)
    end

    it "rejects reusing an idempotency key across two different orders" do
      other_order = create(:order, merchant: merchant)
      initiate(order.reference, idempotency_key: "shared-key")

      initiate(other_order.reference, idempotency_key: "shared-key")

      expect(response).to have_http_status(:conflict)
    end

    it "returns 404 for another merchant's order" do
      other_order = create(:order, merchant: create(:merchant))

      initiate(other_order.reference)

      expect(response).to have_http_status(:not_found)
    end

    it "rejects requests without a valid token" do
      initiate(order.reference, headers: {})

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/payments/:reference" do
    it "returns the payment when it belongs to the authenticated merchant" do
      payment = create(:payment, order: order)

      get "/api/v1/payments/#{payment.reference}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["reference"]).to eq(payment.reference)
      expect(response.parsed_body["order_reference"]).to eq(order.reference)
    end

    it "returns 404 for another merchant's payment" do
      other_order = create(:order, merchant: create(:merchant))
      other_payment = create(:payment, order: other_order)

      get "/api/v1/payments/#{other_payment.reference}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
