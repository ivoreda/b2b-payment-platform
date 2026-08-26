require "rails_helper"

RSpec.describe "Webhooks::PaymentProvider", type: :request do
  let(:order) { create(:order) }
  let(:payment) { create(:payment, order: order) }

  def signed_post(body_hash)
    body = body_hash.to_json
    headers = {
      "Content-Type" => "application/json",
      "X-Webhook-Signature" => Webhooks::SignatureVerifier.header_for(body)
    }

    post "/webhooks/payment_provider", params: body, headers: headers
  end

  def succeeded_payload(payment, event_id: "evt_1")
    {
      id: event_id,
      type: "payment.succeeded",
      data: { payment_reference: payment.reference, provider_reference: "mock_ch_1" }
    }
  end

  it "accepts a validly signed event, enqueues processing, and returns 200 immediately" do
    expect {
      perform_enqueued_jobs do
        signed_post(succeeded_payload(payment))
      end
    }.to change(WebhookEvent, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(payment.reload).to be_succeeded
  end

  it "rejects a request with no signature header, with no state change" do
    body = succeeded_payload(payment).to_json

    expect {
      post "/webhooks/payment_provider", params: body, headers: { "Content-Type" => "application/json" }
    }.not_to change(WebhookEvent, :count)

    expect(response).to have_http_status(:unauthorized)
    expect(payment.reload).to be_pending
  end

  it "rejects a request with an invalid signature, with no state change" do
    body = succeeded_payload(payment).to_json

    expect {
      post "/webhooks/payment_provider", params: body,
                                          headers: { "Content-Type" => "application/json", "X-Webhook-Signature" => "t=#{Time.now.to_i},v1=#{'0' * 64}" }
    }.not_to change(WebhookEvent, :count)

    expect(response).to have_http_status(:unauthorized)
    expect(payment.reload).to be_pending
  end

  it "rejects a malformed JSON body with 400, not 500" do
    body = "not valid json"
    headers = { "Content-Type" => "application/json", "X-Webhook-Signature" => Webhooks::SignatureVerifier.header_for(body) }

    post "/webhooks/payment_provider", params: body, headers: headers

    expect(response).to have_http_status(:bad_request)
  end

  it "returns 400 when the payload is missing id/type" do
    signed_post({ data: {} })

    expect(response).to have_http_status(:bad_request)
  end

  it "treats a redelivered provider_event_id as a no-op, without enqueuing a second job" do
    payload = succeeded_payload(payment, event_id: "evt_dup")

    perform_enqueued_jobs { signed_post(payload) }

    expect {
      signed_post(payload)
    }.not_to change(WebhookEvent, :count)

    expect(response).to have_http_status(:ok)
    expect(payment.reload.payment_events.count).to eq(1)
  end

  it "stores the event as ignored, without a 500, when the payment_reference is unknown" do
    payload = { id: "evt_unknown", type: "payment.succeeded", data: { payment_reference: "pay_does_not_exist" } }

    perform_enqueued_jobs { signed_post(payload) }

    expect(response).to have_http_status(:ok)
    expect(WebhookEvent.last).to be_ignored
  end
end
