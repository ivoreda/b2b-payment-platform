require "rails_helper"

# Rack::Attack is disabled by default in test (config/initializers/rack_attack.rb)
# so the rest of the suite isn't at the mercy of shared throttle-cache state
# across examples. These specs turn it on deliberately and clean up after
# themselves so nothing here leaks into other files.
RSpec.describe "Rate limiting", type: :request do
  around do |example|
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rack::Attack.enabled = false
  end

  it "throttles repeated login attempts from the same IP" do
    11.times { post "/login", params: { email: "nobody@example.com", password: "wrong" } }

    expect(response).to have_http_status(:too_many_requests)
    expect(response.parsed_body["error"]).to eq("Rate limit exceeded")
  end

  it "does not throttle a webhook request until well past normal usage" do
    merchant = create(:merchant)
    payment = create(:payment, order: create(:order, merchant: merchant))
    body = { id: "evt_1", type: "payment.succeeded", data: { payment_reference: payment.reference, provider_reference: "x" } }.to_json
    headers = { "Content-Type" => "application/json", "X-Webhook-Signature" => Webhooks::SignatureVerifier.header_for(body) }

    post "/webhooks/payment_provider", params: body, headers: headers

    expect(response).to have_http_status(:ok)
  end

  it "throttles repeated webhook deliveries from the same IP past the limit" do
    body = { id: "evt_flood", type: "payment.succeeded", data: {} }.to_json
    headers = { "Content-Type" => "application/json", "X-Webhook-Signature" => Webhooks::SignatureVerifier.header_for(body) }

    61.times { post "/webhooks/payment_provider", params: body, headers: headers }

    expect(response).to have_http_status(:too_many_requests)
  end

  it "throttles repeated API requests from the same IP even with a valid token" do
    credential = create(:api_credential)
    headers = { "Authorization" => "Bearer #{credential.token}" }

    301.times { get "/api/v1/orders", headers: headers }

    expect(response).to have_http_status(:too_many_requests)
  end

  it "throttles a single leaked token across many requests even as the IP rotates" do
    credential = create(:api_credential)
    headers = { "Authorization" => "Bearer #{credential.token}" }

    301.times { |i| get "/api/v1/orders", headers: headers.merge("REMOTE_ADDR" => "10.0.#{i / 255}.#{i % 255}") }

    expect(response).to have_http_status(:too_many_requests)
  end

  it "does not throttle a normal volume of API requests" do
    credential = create(:api_credential)
    headers = { "Authorization" => "Bearer #{credential.token}" }

    10.times { get "/api/v1/orders", headers: headers }

    expect(response).to have_http_status(:ok)
  end

  it "throttles repeated signups from the same IP" do
    6.times do |i|
      post signup_path, params: {
        merchant: { name: "Flood Co #{i}" },
        user: { email: "flood#{i}@example.com", password: "password123", password_confirmation: "password123" }
      }
    end

    expect(response).to have_http_status(:too_many_requests)
  end
end
