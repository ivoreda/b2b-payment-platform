require "rails_helper"

# Exercises the full loop end-to-end exactly as an integration would: create
# an order, initiate a payment, let the (simulated) async notification run,
# and confirm the final status via the same API a real client would poll.
# No real network calls happen anywhere in this - MockPaymentProvider fakes
# the round trip, but every step of verify/dedupe/lock/transition is real.
RSpec.describe "Payment lifecycle", type: :request do
  include ActiveJob::TestHelper

  let(:merchant) { create(:merchant) }
  let(:credential) { create(:api_credential, merchant: merchant) }
  let(:auth_headers) { { "Authorization" => "Bearer #{credential.token}" } }

  def create_order(amount_cents:)
    post "/api/v1/orders",
         params: { order: { amount_cents: amount_cents, currency: "usd", customer_email: "buyer@example.com", customer_name: "Buyer Co" } },
         headers: auth_headers, as: :json
    response.parsed_body["reference"]
  end

  def initiate_payment(order_reference)
    post "/api/v1/orders/#{order_reference}/payments",
         headers: auth_headers.merge("Idempotency-Key" => SecureRandom.uuid), as: :json
    response.parsed_body["reference"]
  end

  it "goes from order creation to a succeeded payment with no real network calls" do
    order_reference = create_order(amount_cents: 5_000)

    payment_reference = nil
    perform_enqueued_jobs do
      payment_reference = initiate_payment(order_reference)
    end

    get "/api/v1/payments/#{payment_reference}", headers: auth_headers
    expect(response.parsed_body).to include("status" => "succeeded", "provider_reference" => be_present)

    get "/api/v1/orders/#{order_reference}", headers: auth_headers
    expect(response.parsed_body["status"]).to eq("paid")
  end

  it "goes from order creation to a failed, retryable payment for a declined amount" do
    order_reference = create_order(amount_cents: 1_099)

    payment_reference = nil
    perform_enqueued_jobs do
      payment_reference = initiate_payment(order_reference)
    end

    get "/api/v1/payments/#{payment_reference}", headers: auth_headers
    expect(response.parsed_body).to include("status" => "failed", "failure_reason" => "card_declined")

    get "/api/v1/orders/#{order_reference}", headers: auth_headers
    expect(response.parsed_body["status"]).to eq("awaiting_payment")

    # A failed payment doesn't block retrying with a fresh attempt.
    retry_reference = nil
    perform_enqueued_jobs { retry_reference = initiate_payment(order_reference) }
    expect(retry_reference).not_to eq(payment_reference)
  end
end
