require "rails_helper"

RSpec.describe "Dashboard::Payments", type: :request do
  include ActiveJob::TestHelper

  let(:merchant) { create(:merchant) }
  let(:user) { create(:user, merchant: merchant, password: "password123") }
  let(:order) { create(:order, merchant: merchant) }

  def login_as(user)
    post login_path, params: { email: user.email, password: "password123" }
  end

  it "initiates a payment and redirects back to the order" do
    login_as(user)

    perform_enqueued_jobs do
      post dashboard_order_payments_path(order), params: { idempotency_key: SecureRandom.uuid }
    end

    expect(response).to redirect_to(dashboard_order_path(order))
    expect(order.payments.count).to eq(1)
  end

  it "collapses a double-submit (same idempotency key) into a single payment" do
    login_as(user)
    key = SecureRandom.uuid

    expect {
      post dashboard_order_payments_path(order), params: { idempotency_key: key }
      post dashboard_order_payments_path(order), params: { idempotency_key: key }
    }.to change(Payment, :count).by(1)
  end

  it "allows a fresh retry (new key) after a decline, since the order stays retryable" do
    login_as(user)
    declining_order = create(:order, merchant: merchant, amount_cents: 1_099)

    perform_enqueued_jobs do
      post dashboard_order_payments_path(declining_order), params: { idempotency_key: SecureRandom.uuid }
    end
    expect(declining_order.reload).to be_awaiting_payment

    expect {
      post dashboard_order_payments_path(declining_order), params: { idempotency_key: SecureRandom.uuid }
    }.to change(Payment, :count).by(1)
  end

  it "returns 404 for another merchant's order" do
    login_as(user)
    other_order = create(:order, merchant: create(:merchant))

    post dashboard_order_payments_path(other_order), params: { idempotency_key: SecureRandom.uuid }

    expect(response).to have_http_status(:not_found)
  end

  it "redirects to login when logged out" do
    post dashboard_order_payments_path(order), params: { idempotency_key: SecureRandom.uuid }

    expect(response).to redirect_to(login_path)
  end
end
